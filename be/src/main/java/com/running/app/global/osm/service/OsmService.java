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
        final int MIN_ZOOM = 16;

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
}
