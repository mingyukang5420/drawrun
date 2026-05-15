package com.running.app.domain.editor.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.course.service.DifficultyService;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.coursedraft.service.CourseDraftService;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.repository.TrackRepository;
import com.running.app.domain.track.service.TrackService;
import com.running.app.global.osm.service.OsmService;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.MultiLineString;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

// 에디터 드래프트 영속화만 담당.
// EditorService(=Facade) 가 트랜잭션 밖에서 디스크 IO/보상을 처리하고,
// 이 컴포넌트는 자기 자신이 받은 trackImageUrl 을 그대로 신뢰해서 DB 작업만 수행한다.
// 분리 이유: @Transactional 안에서 디스크 IO 가 일어나면 트랜잭션 보유 시간이 IO 만큼 늘어나고
//           DB 커넥션이 그 동안 점유된다. 영속화 책임만 별도 빈으로 빼서 self-invocation 없이
//           Facade 에서 try-catch + 보상이 가능하도록 한다.
@Component
@RequiredArgsConstructor
public class EditorDraftSaver {

    // 좌표 검증 시 OsmSplit buffer 허용 오차(미터).
    // 부동소수점 직렬화/역직렬화 오차 흡수용 안전망. 도로 폭보다 훨씬 작아 오인 매칭 위험 X.
    private static final double WALKABLE_BUFFER_METERS = 1.0;

    private final MemberRepository memberRepository;
    private final CourseDraftRepository courseDraftRepository;
    private final TrackRepository trackRepository;
    private final RunningRecordRepository runningRecordRepository;
    private final OsmService osmService;
    private final TrackService trackService;
    private final CourseDraftService courseDraftService;
    private final DifficultyService difficultyService;
    private final ChallengeRepository challengeRepository;

    @Transactional
    public EditorResponse.SaveResponse save(
            String loginId,
            EditorRequest.SaveRequest request,
            String trackImageUrl
    ) {
        // 1. JwtAuthFilter 가 principal 로 등록한 loginId 로 Member 조회
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        // 2. order 정렬 + Track 입력 모델로 변환
        List<TrackRequest.NodeDTO> sortedNodes = EditorConverter.toSortedTrackNodes(
                request.getCoordinates()
        );

        // 3. 좌표 검증 (osm_ways_split 위에 모두 있는지) — 실패 시 트랜잭션 롤백되며 호출자가 디스크 보상
        osmService.validateAllPointsWalkable(sortedNodes, WALKABLE_BUFFER_METERS);

        // 4. MultiLineString 생성 + Track 영속화 (거리는 PostGIS ST_Length 자동 계산)
        MultiLineString geom = trackService.createMultiLineString(sortedNodes);
        Track track = trackService.createTrackFromEditor(geom, trackImageUrl);

        // 5. CourseDraft 영속화 (status=READY 로 시작)
        CourseDifficulty difficulty = difficultyService.calculate(track);

        Challenge challenge = null;

        // challengeId가 있는 경우
        if (request.getChallengeId() != null) {
            challenge = challengeRepository.findById(request.getChallengeId())
                    .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));
        }

        CourseDraft courseDraft = courseDraftService.createFromEditor(
                memberId,
                track,
                request.getTitle(),
                difficulty,
                challenge
        );

        return EditorConverter.toSaveResponse(courseDraft);
    }

    // 에디터 PATCH 선행 검증 — read-only 트랜잭션.
    // Facade 가 디스크 IO 들어가기 전에 호출. 권한/상태 실패면 throw → IO 안 일어남.
    // 정상 통과 시 좌표 변경 여부만 boolean 으로 반환 (facade 가 썸네일 저장 여부 분기에 사용).
    // 트랜잭션 안의 update() 에서 좌표 비교를 다시 하므로 TOCTOU 안전망 존재.
    @Transactional(readOnly = true)
    public boolean precheckUpdate(
            String loginId,
            Long courseDraftId,
            EditorRequest.UpdateRequest request
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        if (!courseDraft.getMemberId().equals(member.getMemberId().longValue())) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        if (courseDraft.getStatus() != CourseDraftStatus.READY) {
            throw new GeneralException(ErrorStatus.EDITOR_NOT_EDITABLE);
        }

        return !EditorConverter.coordinatesEqual(courseDraft.getTrack(), request.getCoordinates());
    }

    // 트랜잭션을 service에서 호출되는 메서드에 따로 걸어둠으로써 디스크 I/O로 인한 블로킹 방지
    @Transactional
    public UpdateOutcome update(
            String loginId,
            Long courseDraftId,
            EditorRequest.UpdateRequest request,
            String newTrackImageUrl
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        // 한번 더 권한 및 삭제 가능 상태 검증. 아주 약간의 시간 차이로 인해 상태가 변경되었을 때를 대비한 방어로직
        if (!courseDraft.getMemberId().equals(memberId)) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        if (courseDraft.getStatus() != CourseDraftStatus.READY) {
            throw new GeneralException(ErrorStatus.EDITOR_NOT_EDITABLE);
        }

        boolean titleChanged = !courseDraft.getTitle().equals(request.getTitle());
        boolean coordinatesChanged = !EditorConverter.coordinatesEqual(
                courseDraft.getTrack(), request.getCoordinates()
        );

        String oldTrackImageUrl = null;

        if (coordinatesChanged) {
            // precheck 단계에선 미변경으로 봐 newTrackImageUrl 이 만들어지지 않은 상태
            // 좌표만 변경된 상태로 들어온 경우 썸네일이 없으므로 저장할 수 없음
            if (newTrackImageUrl == null) {
                throw new GeneralException(
                        ErrorStatus.INVALID_IMAGE_FILE,
                        "좌표 변경 시 썸네일이 필요합니다."
                );
            }

            List<TrackRequest.NodeDTO> sortedNodes = EditorConverter.toSortedTrackNodes(
                    request.getCoordinates()
            );
            osmService.validateAllPointsWalkable(sortedNodes, WALKABLE_BUFFER_METERS);

            MultiLineString geom = trackService.createMultiLineString(sortedNodes);
            Track newTrack = trackService.createTrackFromEditor(geom, newTrackImageUrl);

            Long oldTrackId = courseDraft.getTrack().getTrackId();
            oldTrackImageUrl = courseDraft.getTrack().getTrackImageUrl();

            courseDraft.changeTrack(newTrack);
            courseDraft.changeDifficulty(difficultyService.calculate(newTrack));

            // existsBy 호출 시 auto-flush 가 트랙 변경사항 UPDATE 를 먼저 반영 → FK 위반 회피.
            // status=READY 인 드래프트의 이전 Track 은 사실상 RunningRecord 참조 없음이 정상이지만,
            // 운영 중 예외 흐름으로 참조가 남았을 가능성이 있어 방어적으로 확인.
            if (!runningRecordRepository.existsByTrack_TrackId(oldTrackId)) {
                trackRepository.deleteById(oldTrackId);
            }
        }

        if (titleChanged) {
            courseDraft.changeTitle(request.getTitle());
        }

        return new UpdateOutcome(
                coordinatesChanged,
                oldTrackImageUrl,
                EditorConverter.toDraftDetailResponse(courseDraft, false)
        );
    }

    // PATCH 결과를 facade 에 전달하기 위한 내부 데이터 서빙 DTO
    // coordinatesChanged: facade 가 이전 썸네일 디스크 삭제 분기를 탈지 결정(좌표 유무로 결정됨)
    // oldTrackImageUrl: 이전 썸네일의 디스크 경로 (좌표 미변경이면 null)
    // response: 그대로 클라이언트에게 돌려줄 응답 DTO
    public record UpdateOutcome(
            boolean coordinatesChanged,
            String oldTrackImageUrl,
            EditorResponse.DraftDetailResponse response
    ) {

    }
}
