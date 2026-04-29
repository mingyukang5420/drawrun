package com.running.app.domain.track.service;

import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.repository.TrackRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) //읽기 전용으로 두기
public class TrackService {

    private static final int SRID = 4326;

    private final TrackRepository trackRepository;

    // 노드를 멀티라인스트링 변환 -> 엔티티 생성 -> 저장 / 저장을 위해 Transactional 어노테이션 사용
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

    private MultiLineString createMultiLineString(List<TrackRequest.NodeDTO> nodes){
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
