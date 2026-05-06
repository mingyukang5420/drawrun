package com.running.app.domain.editor.service;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.repository.CourseDistrictRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.course.service.CourseService;
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

    private final OsmService osmService;
    private final TrackService trackService;
    private final CourseService courseService;
    private final MemberRepository memberRepository;
    private final CourseRepository courseRepository;
    private final CourseDistrictRepository courseDistrictRepository;
    private final TrackRepository trackRepository;
    private final RunningRecordRepository runningRecordRepository;

    // 에디터로 그린 커스텀 코스 저장.
    // 검증 실패 시 INVALID_ROUTE throw → 트랜잭션 롤백 (Track / Course 모두 미저장).
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

        // 5. Course 영속화 (record_id=null, registered_at=null → status=READY)
        Course course = courseService.createFromEditor(memberId, track, request.getTitle());

        // 6. 응답 변환
        return EditorConverter.toSaveResponse(course);
    }

    @Transactional
    public void delete(String loginId, Long courseId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        // 삭제를 요청한 사용자와 course를 등록한 사용자가 다르면 권한 없음
        if (course.getMemberId().longValue() != member.getMemberId()) {
            throw new GeneralException(ErrorStatus.FORBIDDEN);
        }

        // 만약 course가 등록되어있다면 삭제할 수 없음
        if (course.getRegisteredAt() != null) {
            throw new GeneralException(ErrorStatus.ALREADY_REGISTERED_COURSE);
        }

        // 삭제 후엔 course 가 영속성 컨텍스트에서 사라지므로 Track ID 를 미리 캐싱
        Long trackId = course.getTrack().getTrackId();

        // Course 삭제 전 course_district 자식 행 먼저 정리 (FK 위반 방지)
        courseDistrictRepository.deleteByCourseId(courseId);
        courseRepository.deleteById(courseId);

        // Track 미참조 시에만 동반 삭제 — RunningRecord 가 참조 중이면 보존
        if (!runningRecordRepository.existsByTrack_TrackId(trackId)) {
            trackRepository.deleteById(trackId);
        }
    }
}
