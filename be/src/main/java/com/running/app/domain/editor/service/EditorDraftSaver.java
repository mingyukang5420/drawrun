package com.running.app.domain.editor.service;

import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.service.CourseDraftService;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
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
    private final OsmService osmService;
    private final TrackService trackService;
    private final CourseDraftService courseDraftService;

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
        CourseDifficulty difficulty = determineDifficulty(track.getDistance());
        CourseDraft courseDraft = courseDraftService.createFromEditor(
                memberId,
                track,
                request.getTitle(),
                difficulty
        );

        return EditorConverter.toSaveResponse(courseDraft);
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
