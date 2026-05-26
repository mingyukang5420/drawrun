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

    // 입력 좌표에서 가장 가까운 osm_ways 노드의 고도값 반환
    // elevation_nodes 컬럼은 {"lat":..., "lng":..., "elev":...} 형태의 JSON 객체 배열
    @Query(
            value = """
                    WITH nearest_way AS (
                        SELECT geom, elevation_nodes
                        FROM osm_ways
                        WHERE elevation_nodes IS NOT NULL
                        ORDER BY geom::geography <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
                        LIMIT 1
                    ),
                    node_distances AS (
                        SELECT (dp).path[1] AS idx, (dp).geom AS node_geom, elevation_nodes
                        FROM nearest_way, LATERAL ST_DumpPoints(geom) AS dp
                    )
                    SELECT (elevation_nodes[idx]->>'elev')::double precision
                    FROM node_distances
                    ORDER BY ST_Distance(node_geom::geography, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography)
                    LIMIT 1
                    """,
            nativeQuery = true
    )
    Double findNearestNodeElevation(@Param("lng") Double lng, @Param("lat") Double lat);
}
