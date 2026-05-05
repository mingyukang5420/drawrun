package com.running.app.domain.editor.converter;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse.Geom;
import com.running.app.domain.editor.dto.EditorResponse.SaveResponse;
import com.running.app.domain.editor.dto.EditorResponse.WayInnerResponse;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.global.osm.entity.OsmSplit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.LineString;

public abstract class EditorConverter {

    // EditorRequest 의 NodeDTO 들을 order 기준 오름차순 정렬한 후
    // 하위 서비스(OsmService, TrackService) 가 받는 TrackRequest.NodeDTO 로 변환.
    // order 의 역할은 여기까지 — 정렬된 시퀀스가 곧 좌표 순서가 됨.
    public static List<TrackRequest.NodeDTO> toSortedTrackNodes(
            List<EditorRequest.SaveRequest.NodeDTO> coordinates
    ) {
        return coordinates.stream()
                .sorted(Comparator.comparingInt(EditorRequest.SaveRequest.NodeDTO::getOrder))
                .map(node -> new TrackRequest.NodeDTO(node.getLat(), node.getLng()))
                .toList();
    }

    // 영속화된 Course → 응답 DTO. status 는 Course 의 도메인 메서드(getStatus)로 도출.
    // isValidRoute 는 검증 통과 후에만 응답이 만들어지므로 항상 true.
    public static SaveResponse toSaveResponse(Course course) {
        return SaveResponse.builder()
                .editorId(course.getId())
                .title(course.getTitle())
                .status(course.getStatus().name())
                .isValidRoute(true)
                .build();
    }

    // 서비스 로직의 반환값으로 나온 osmWayList -> WayResponse 응답 규격에 맞추어 변환
    public static WayResponse toWayResponse(List<OsmSplit> osmWayList) {

        List<WayInnerResponse> ways = new ArrayList<>();

        // osmWayList -> WayInnerResponse 중첩 dto 변환
        for (OsmSplit split : osmWayList) {
            WayInnerResponse wayInnerResponse = WayInnerResponse.builder()
                    .osmId(split.getOsmWay().getOsmId())
                    .highway(split.getOsmWay().getHighway())
                    .name(split.getOsmWay().getName())
                    .geom(toGeom(split.getGeom()))
                    .build();

            ways.add(wayInnerResponse);
        }

        return WayResponse.builder().ways(ways).build();
    }

    // LineString -> 응답을 위한 Geom 클래스로 변환하기 위한 헬퍼 메서드
    private static Geom toGeom(LineString lineString) {

        // 인자로 받은 LineString의 좌표 배열을 꺼내서 Geom으로 변환
        Coordinate[] coordinates = lineString.getCoordinates();
        List<Double[]> coordinateList = new ArrayList<>();

        // 좌표를 뜯어서 리스트로 재조립함
        for (Coordinate coordinate : coordinates) {

            double lng = coordinate.getX();
            double lat = coordinate.getY();
            Double[] coordinateArray = {lng, lat};
            coordinateList.add(coordinateArray);
        }

        return Geom.builder()
                .type("LineString")
                .coordinates(coordinateList)
                .build();
    }

}
