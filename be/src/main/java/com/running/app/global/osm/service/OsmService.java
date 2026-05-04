package com.running.app.global.osm.service;

import com.running.app.global.osm.entity.OsmSplit;
import com.running.app.global.osm.repository.OsmSplitRepository;
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

}
