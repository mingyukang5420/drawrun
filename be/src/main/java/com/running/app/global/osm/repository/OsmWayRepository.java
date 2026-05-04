package com.running.app.global.osm.repository;

import com.running.app.global.osm.entity.OsmWay;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OsmWayRepository extends JpaRepository<OsmWay, Long> {

    // 최소 위경도, 최대 위경도로 만든 직사각형과 겹치는 경로 객체를 반환
    @Query("SELECT w FROM OsmWay w WHERE ST_Intersects(w.geom, ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326))")
    List<OsmWay> findWaysInBbox(
            @Param("minLng") Double minLng,
            @Param("minLat") Double minLat,
            @Param("maxLng") Double maxLng,
            @Param("maxLat") Double maxLat
    );
}
