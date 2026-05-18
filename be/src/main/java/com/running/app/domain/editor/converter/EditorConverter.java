package com.running.app.domain.editor.converter;

import com.running.app.domain.coursedraft.dto.CourseDraftListItem;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse.DraftDetailResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftListResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftListResultResponse;
import com.running.app.domain.editor.dto.EditorResponse.Geom;
import com.running.app.domain.editor.dto.EditorResponse.SaveResponse;
import com.running.app.domain.editor.dto.EditorResponse.WayInnerResponse;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.global.osm.entity.OsmSplit;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.LineString;
import org.springframework.data.domain.Slice;

public abstract class EditorConverter {

    // 좌표 동일성 비교용 허용 오차(도, degree).
    // 부동소수점 직렬화/역직렬화 round-trip 으로 마지막 자릿수가 흔들리는 케이스 흡수.
    // 1e-9 도 ≈ 적도 기준 0.1mm — 사람이 그릴 수 있는 정밀도보다 훨씬 작아 오인 위험 X.
    private static final double COORD_EPSILON_DEG = 1e-9;

    // 기존 Track 의 좌표 시퀀스와 요청 좌표 시퀀스가 동일한지 비교.
    // - 요청 좌표는 order 기준으로 정렬한 뒤 비교 (FE 가 순서 섞어 보낼 가능성 대응)
    // - 길이 다르면 즉시 false
    // - lat/lng 차이가 epsilon 안에 들어오면 동일로 판정
    public static boolean coordinatesEqual(
            Track existingTrack,
            List<EditorRequest.SaveRequest.NodeDTO> requestCoordinates
    ) {
        List<TrackRequest.NodeDTO> existing = TrackConverter.toNodeDTOList(existingTrack);
        List<TrackRequest.NodeDTO> sorted = toSortedTrackNodes(requestCoordinates);

        if (existing.size() != sorted.size()) {
            return false;
        }
        for (int i = 0; i < existing.size(); i++) {
            if (Math.abs(existing.get(i).getLat() - sorted.get(i).getLat()) > COORD_EPSILON_DEG) {
                return false;
            }
            if (Math.abs(existing.get(i).getLng() - sorted.get(i).getLng()) > COORD_EPSILON_DEG) {
                return false;
            }
        }
        return true;
    }

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

    // 영속화된 CourseDraft → 응답 DTO.
    // 내부 enum 값(READY/DONE) 과 응답 contract 가 동일해서 별도 매핑 없이 .name() 으로 직결.
    // isValidRoute 는 검증 통과 후에만 응답이 만들어지므로 항상 true.
    public static SaveResponse toSaveResponse(CourseDraft courseDraft) {
        return SaveResponse.builder()
                .courseDraftId(courseDraft.getId())
                .title(courseDraft.getTitle())
                .status(courseDraft.getStatus().name())
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

    // 에디터 목록 조회 — 단일 항목 변환.
    // difficulty / status 는 Projection 의 enum 값을 .name() 으로 String 화.
    // distance 는 소수점 1째 자리 반올림, createdAt 은 YYYY-MM-DD 문자열로 가공.
    public static DraftListResponse toDraftListResponse(CourseDraftListItem item) {
        return DraftListResponse.builder()
                .courseDraftId(item.getCourseDraftId())
                .courseId(item.getCourseId())
                .title(item.getTitle())
                .difficulty(item.getDifficulty().name())
                .status(item.getStatus().name())
                .distance(formatDistance(item.getDistance()))
                .trackImageUrl(item.getTrackImageUrl())
                .createdAt(formatDate(item.getCreatedAt()))
                .build();
    }

    // 거리 표현용 — 소수점 1째 자리에서 반올림. 단위(km) 는 FE 책임.
    private static Double formatDistance(Double distance) {
        if (distance == null) {
            return null;
        }
        return Math.round(distance * 10.0) / 10.0;
    }

    // 날짜 표현용 — YYYY-MM-DD. CourseConverter.formatDate 와 동일 포맷(목록 카드 일관성).
    private static String formatDate(LocalDateTime dateTime) {
        if (dateTime == null) {
            return null;
        }
        return String.format(
                "%d-%02d-%02d",
                dateTime.getYear(),
                dateTime.getMonthValue(),
                dateTime.getDayOfMonth()
        );
    }

    // 에디터 목록 조회 — Slice 결과를 wrapper 응답으로 변환.
    public static DraftListResultResponse toDraftListResultResponse(
            Slice<CourseDraftListItem> slice,
            List<DraftListResponse> content
    ) {
        return DraftListResultResponse.builder()
                .content(content)
                .page(slice.getNumber())
                .size(slice.getSize())
                .hasNext(slice.hasNext())
                .build();
    }

    // 에디터 목록 조회(챌린지에 따른) — Slice 결과를 wrapper 응답으로 변환.
    public static DraftListResultResponse toDraftListResultResponseV2(
            Slice<CourseDraftListItem> slice,
            List<DraftListResponse> content,
            String challengeTitle
    ) {
        return DraftListResultResponse.builder()
                .content(content)
                .page(slice.getNumber())
                .size(slice.getSize())
                .hasNext(slice.hasNext())
                .challengeTitle(challengeTitle)
                .build();
    }

    // 에디터 상세 조회 응답 변환.
    // status 는 등록 여부에 따라 derived: 등록되어 있으면 "REGISTERED",
    // 아니면 draft 자체 상태(READY/DONE) 의 .name() 을 그대로 노출.
    // coordinates 는 Track 의 MultiLineString 좌표를 NodeDTO 시퀀스로 풀어서 노출.
    public static DraftDetailResponse toDraftDetailResponse(
            CourseDraft draft,
            boolean isRegistered
    ) {
        String status = isRegistered ? "REGISTERED" : draft.getStatus().name();

        return DraftDetailResponse.builder()
                .courseDraftId(draft.getId())
                .title(draft.getTitle())
                .status(status)
                .coordinates(TrackConverter.toNodeDTOList(draft.getTrack()))
                .build();
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
