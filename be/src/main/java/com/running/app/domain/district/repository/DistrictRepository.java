package com.running.app.domain.district.repository;

import com.running.app.domain.district.entity.District;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface DistrictRepository extends JpaRepository<District, String> {

    List<District> findAllByGuIn(List<String> guList);

    @Query(
        value = "SELECT * FROM districts d WHERE ST_Intersects(d.boundary, ST_GeomFromText(:wkt, 4326))",
        nativeQuery = true
    )
    List<District> findDistrictsByGeomIntersects(@Param("wkt") String wkt);
}