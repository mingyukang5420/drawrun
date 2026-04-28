package com.running.app.global.response.osm.service;

import com.running.app.global.response.osm.entity.OsmWay;
import com.running.app.global.response.osm.repository.OsmWayRepository;
import java.util.Collections;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class OsmService {

    private final OsmWayRepository osmWayRepository;

    public List<OsmWay> getWalkableWays(Double minLat, Double minLng, Double maxLat, Double maxLng,
            Integer zoom) {

        // zoom 레벨 검증
        // 요청으로 들어온 줌 레벨이 이 상수보다 작다면 좌표 배열 반환하지 않음
        final int MIN_ZOOM = 16;

        if (zoom < MIN_ZOOM) {
            return Collections.emptyList();
        }

        return osmWayRepository.findWaysInBbox(minLng, minLat, maxLng, maxLat);
    }

}
