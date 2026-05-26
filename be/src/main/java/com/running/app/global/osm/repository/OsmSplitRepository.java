package com.running.app.global.osm.repository;

import com.running.app.global.osm.entity.OsmSplit;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OsmSplitRepository extends JpaRepository<OsmSplit, Long> {

    // 최소 위경도, 최대 위경도로 만든 직사각형과 겹치는 경로 객체를 반환
    @Query("SELECT w FROM OsmSplit w JOIN FETCH w.osmWay WHERE ST_Intersects(w.geom, ST_MakeEnvelope(:minLng, :minLat, :maxLng, :maxLat, 4326))")
    List<OsmSplit> findWaysInBbox(
            @Param("minLng") Double minLng,
            @Param("minLat") Double minLat,
            @Param("maxLng") Double maxLng,
            @Param("maxLat") Double maxLat
    );

    // (lng, lat) 좌표가 OsmSplit 의 epsilon(미터) buffer 내에 존재하는지 검사.
    // 클라이언트가 받은 도보 가능한 길(osm_ways_split) 위에 있는지 확인 — 한 좌표라도 false 면 호출자가 INVALID_ROUTE 처리.
    @Query(
            value = """
                    SELECT EXISTS (
                        SELECT 1 FROM osm_ways_split s
                        WHERE ST_DWithin(
                            s.geom::geography,
                            ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                            :epsilon
                        )
                    )
                    """,
            nativeQuery = true
    )
    boolean existsSplitNearPoint(
            @Param("lng") Double lng,
            @Param("lat") Double lat,
            @Param("epsilon") Double epsilon
    );

    // 트랙(WKT) 주변 epsilonMeters 이내 안전 도로 세그먼트를 합쳐 WKT로 반환.
    // 해당 범위 내 세그먼트가 없으면 'MULTILINESTRING EMPTY' 반환.
    @Query(
            value = """
                    SELECT COALESCE(
                        ST_AsText(ST_Union(geom)),
                        'MULTILINESTRING EMPTY'
                    )
                    FROM osm_ways_split
                    WHERE ST_DWithin(
                        geom::geography,
                        ST_GeomFromText(:wkt, 4326)::geography,
                        :epsilonMeters
                    )
                    """,
            nativeQuery = true
    )
    String findUnionWktNearGeom(
            @Param("wkt") String wkt,
            @Param("epsilonMeters") double epsilonMeters
    );
}
