package com.running.app.domain.editor.service;

import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.dto.CourseDraftListItem;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.coursedraft.service.CourseDraftService;
import com.running.app.domain.coursedraft.type.CourseDraftFilterType;
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
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.MultiLineString;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EditorService {

    // 좌표 검증 시 OsmSplit buffer 허용 오차(미터).
    // 부동소수점 직렬화/역직렬화 오차 흡수용 안전망. 도로 폭보다 훨씬 작아 오인 매칭 위험 X.
    private static final double WALKABLE_BUFFER_METERS = 1.0;

    // 에디터 목록 페이지 크기. 무한스크롤 1회 페치 단위.
    private static final int DRAFT_LIST_PAGE_SIZE = 10;

    private final OsmService osmService;
    private final TrackService trackService;
    private final CourseDraftService courseDraftService;
    private final MemberRepository memberRepository;
    private final CourseDraftRepository courseDraftRepository;
    private final TrackRepository trackRepository;
    private final RunningRecordRepository runningRecordRepository;

    // 에디터로 그린 커스텀 코스를 임시 저장(course_drafts INSERT).
    // 검증 실패 시 INVALID_ROUTE throw → 트랜잭션 롤백 (Track / CourseDraft 모두 미저장).
    @Transactional
    public EditorResponse.SaveResponse save(String loginId, EditorRequest.SaveRequest request) {
        // 1. JwtAuthFilter 가 principal 로 등록한 loginId 로 Member 조회 → memberId 추출
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        // 2. order 정렬 + Track 입력 모델(TrackRequest.NodeDTO)로 변환
        List<TrackRequest.NodeDTO> sortedNodes = EditorConverter.toSortedTrackNodes(
                request.getCoordinates()
        );

        // 3. 좌표 검증 (osm_ways_split 위에 모두 있는지)
        osmService.validateAllPointsWalkable(sortedNodes, WALKABLE_BUFFER_METERS);

        // 4. MultiLineString 생성 + Track 영속화 (거리는 PostGIS ST_Length 자동 계산)
        MultiLineString geom = trackService.createMultiLineString(sortedNodes);
        Track track = trackService.createTrackFromEditor(geom);

        // 5. CourseDraft 영속화 (status=DRAFT 로 시작)
        CourseDifficulty difficulty = determineDifficulty(track.getDistance());
        CourseDraft courseDraft = courseDraftService.createFromEditor(
                memberId,
                track,
                request.getTitle(),
                difficulty
        );

        // 6. 응답 변환 (DRAFT → "READY" 매핑)
        return EditorConverter.toSaveResponse(courseDraft);
    }

    @Transactional
    public void delete(String loginId, Long courseDraftId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        // 삭제를 요청한 사용자와 드래프트를 등록한 사용자가 다르면 권한 없음
        if (!courseDraft.getMemberId().equals(member.getMemberId().longValue())) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        // [임시 안전망] DONE 상태는 정식 코스 등록 가능 후보이므로 일단 차단.
        // TODO: 본래 조건은 "draft → record → course 체인이 형성된 경우(= 정식 등록 완료)에만 차단".
        //       다른 팀원 영역(RunningRecord.courseDraftId, Course.sourceRecordId) 합류 시 이 분기는 제거하고
        //       아래 isDeletable 호출이 정확한 차단을 담당한다.
        if (courseDraft.getStatus() == CourseDraftStatus.DONE) {
            throw new GeneralException(ErrorStatus.ALREADY_REGISTERED_COURSE);
        }

        if (!courseDraftService.isDeletable(courseDraftId)) {
            throw new GeneralException(ErrorStatus.ALREADY_REGISTERED_COURSE);
        }

        // 삭제 후엔 courseDraft 가 영속성 컨텍스트에서 사라지므로 Track ID 를 미리 캐싱
        Long trackId = courseDraft.getTrack().getTrackId();

        courseDraftRepository.deleteById(courseDraftId);

        // Track 미참조 시에만 동반 삭제 — RunningRecord 가 참조 중이면 보존
        if (!runningRecordRepository.existsByTrack_TrackId(trackId)) {
            trackRepository.deleteById(trackId);
        }
    }

    // 에디터 목록 조회 — filter 별로 Repository 분기.
    // 정렬은 각 쿼리 안에 created_at DESC 로 명시되어 있어 Pageable 의 Sort 는 사용하지 않는다.
    public EditorResponse.DraftListResultResponse getDraftList(
            String loginId,
            CourseDraftFilterType filter,
            Integer page
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        Pageable pageable = PageRequest.of(page, DRAFT_LIST_PAGE_SIZE);

        Slice<CourseDraftListItem> slice = switch (filter) {
            case ALL -> courseDraftRepository.findAllByMemberId(memberId, pageable);
            case READY -> courseDraftRepository.findAllByMemberIdAndStatus(
                    memberId, CourseDraftStatus.READY, pageable);
            case DONE -> courseDraftRepository.findUnregisteredDoneByMemberId(memberId, pageable);
            case REGISTERED -> courseDraftRepository.findRegisteredByMemberId(memberId, pageable);
        };

        List<EditorResponse.DraftListResponse> content = slice.getContent().stream()
                .map(EditorConverter::toDraftListResponse)
                .toList();

        return EditorConverter.toDraftListResultResponse(slice, content);
    }

    // 거리 기반 난이도 자동 산정.
    // CourseService.determineDifficulty 와 동일 로직(중복) — CourseService 는 변경 금지 범위라 호출 불가.
    // 정식 코스 등록 API 작업 시 공통 위치(CourseDifficulty enum 등)로 통합 리팩터링 예정.
    private CourseDifficulty determineDifficulty(double distanceKm) {
        if (distanceKm < 3.0) {
            return CourseDifficulty.BEGINNER;
        }
        if (distanceKm < 5.0) {
            return CourseDifficulty.EASY;
        }
        if (distanceKm < 10.0) {
            return CourseDifficulty.NORMAL;
        }
        return CourseDifficulty.HARD;
    }
}
