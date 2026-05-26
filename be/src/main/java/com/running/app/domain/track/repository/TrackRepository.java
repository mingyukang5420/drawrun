package com.running.app.domain.track.repository;

import com.running.app.domain.track.entity.Track;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface TrackRepository extends JpaRepository<Track, Long> {

    // PostGIS ST_Length 로 미터 단위 거리 계산.
    // WKT String 으로 받아 SRID 4326 으로 복원 후 geography 캐스팅 (지오이드 기준 미터).
    @Query(
            value = "SELECT ST_Length(ST_GeomFromText(:wkt, 4326)::geography)",
            nativeQuery = true
    )
    Double calculateLengthMeters(@Param("wkt") String wkt);
}
