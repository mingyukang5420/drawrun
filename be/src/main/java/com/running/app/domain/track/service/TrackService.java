package com.running.app.domain.track.service;

import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.repository.TrackRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.geom.MultiLineString;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) //읽기 전용으로 두기
public class TrackService {

    private static final int SRID = 4326;

    private final TrackRepository trackRepository;

    // 자유러닝용 — 클라이언트가 GPS 누적 거리(distance)와 트랙 이미지 URL을 보내줌
    @Transactional
    public Track createTrack(
            List<TrackRequest.NodeDTO> nodes,
            Double distance,
            String trackImageUrl
    ) {
        MultiLineString geom = createMultiLineString(nodes);

        Track track = TrackConverter.toTrack(
                geom,
                distance,
                trackImageUrl
        );

        return trackRepository.save(track);
    }

    // 에디터 저장용 — 클라이언트가 distance를 모르므로 PostGIS로 자동 계산. todo: 트랙 이미지 차후 수정
    @Transactional
    public Track createTrackFromEditor(MultiLineString geom) {
        String wkt = new WKTWriter().write(geom);
        Double distanceMeters = trackRepository.calculateLengthMeters(wkt);
        Double distanceKm = distanceMeters / 1000.0;

        Track track = TrackConverter.toTrack(geom, distanceKm, null);

        return trackRepository.save(track);
    }

    // 좌표 리스트 → MultiLineString 변환. EditorService 도 호출하므로 public
    public MultiLineString createMultiLineString(List<TrackRequest.NodeDTO> nodes) {
        GeometryFactory geometryFactory = new GeometryFactory(
                // Double 정밀도 사용
                new PrecisionModel(),
                SRID
        );

        //lat-lng => lng-lat 순서 변환
        //Coordinate -> JTS에서 좌표 한 점을 표현하는 객체
        Coordinate[] coordinates = nodes.stream()
                .map(node -> new Coordinate(node.getLng(), node.getLat()))
                .toArray(Coordinate[]::new);

        LineString lineString = geometryFactory.createLineString(coordinates);

        //LineString -> MultiLineString
        return geometryFactory.createMultiLineString(new LineString[]{lineString});
    }
}
