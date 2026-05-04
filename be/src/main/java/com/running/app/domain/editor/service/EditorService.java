package com.running.app.domain.editor.service;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.service.CourseService;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.service.TrackService;
import com.running.app.global.osm.service.OsmService;
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

    // 에디터로 그린 커스텀 코스 저장.
    // 검증 실패 시 INVALID_ROUTE throw → 트랜잭션 롤백 (Track / Course 모두 미저장).
    @Transactional
    public EditorResponse.SaveResponse save(Long memberId, EditorRequest.SaveRequest request) {
        // 1. order 정렬 + Track 입력 모델(TrackRequest.NodeDTO)로 변환
        List<TrackRequest.NodeDTO> sortedNodes = EditorConverter.toSortedTrackNodes(
                request.getCoordinates()
        );

        // 2. 좌표 검증 (osm_ways_split 위에 모두 있는지)
        osmService.validateAllPointsWalkable(sortedNodes, WALKABLE_BUFFER_METERS);

        // 3. MultiLineString 생성 + Track 영속화 (거리는 PostGIS ST_Length 자동 계산)
        MultiLineString geom = trackService.createMultiLineString(sortedNodes);
        Track track = trackService.createTrackFromEditor(geom);

        // 4. Course 영속화 (record_id=null, registered_at=null → status=READY)
        Course course = courseService.createFromEditor(memberId, track, request.getTitle());

        // 5. 응답 변환
        return EditorConverter.toSaveResponse(course);
    }
}
