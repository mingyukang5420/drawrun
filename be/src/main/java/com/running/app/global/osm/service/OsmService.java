package com.running.app.global.osm.service;

import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.global.osm.entity.OsmSplit;
import com.running.app.global.osm.repository.OsmSplitRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.Collections;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.MultiLineString;
import org.locationtech.jts.io.ParseException;
import org.locationtech.jts.io.WKTReader;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class OsmService {

    private final OsmSplitRepository osmSplitRepository;

    public List<OsmSplit> getWalkableWays(Double minLat, Double minLng, Double maxLat,
            Double maxLng,
            Integer zoom) {

        // zoom 레벨 검증
        // 요청으로 들어온 줌 레벨이 이 상수보다 작다면 좌표 배열 반환하지 않음
        // TODO: 현재는 테스트를 위해 모든 줌 레벨 허용
        final int MIN_ZOOM = 10;

        if (zoom < MIN_ZOOM) {
            return Collections.emptyList();
        }

        return osmSplitRepository.findWaysInBbox(minLng, minLat, maxLng, maxLat);
    }

    // 좌표 N개 모두가 도보 가능한 길(osm_ways_split)의 epsilon(미터) buffer 내에 있는지 검증.
    // 한 좌표라도 buffer 밖이면 즉시 INVALID_ROUTE throw (early termination).
    public void validateAllPointsWalkable(List<TrackRequest.NodeDTO> nodes, double epsilon) {
        for (TrackRequest.NodeDTO node : nodes) {
            boolean onWalkableWay = osmSplitRepository.existsSplitNearPoint(
                    node.getLng(),
                    node.getLat(),
                    epsilon
            );
            if (!onWalkableWay) {
                log.warn("좌표가 도보 가능한 길에 없음: lng={}, lat={}, epsilon={}",
                        node.getLng(), node.getLat(), epsilon);
                throw new GeneralException(ErrorStatus.INVALID_ROUTE);
            }
        }
    }

    // 사용자 트랙 중 안전 도로(osm_ways_split)가 커버하는 비율을 반환 (0.0 ~ 1.0).
    // searchMeters 이내 안전 도로를 합산 후, bufferDegrees 범위 내에 겹치는 트랙 길이 비율을 계산.
    public double calculateSafeRatio(MultiLineString userGeom, double bufferDegrees, double searchMeters) {
        double userLength = userGeom.getLength();
        if (userLength == 0) return 0.0;

        String safeUnionWkt = osmSplitRepository.findUnionWktNearGeom(userGeom.toText(), searchMeters);
        try {
            Geometry safeRoads = new WKTReader().read(safeUnionWkt);
            if (safeRoads.isEmpty()) return 0.0;

            double coveredLength = userGeom.intersection(safeRoads.buffer(bufferDegrees)).getLength();
            return coveredLength / userLength;
        } catch (ParseException e) {
            log.warn("isSafe WKT 파싱 오류, ratio=0 처리: {}", e.getMessage());
            return 0.0;
        }
    }
}
