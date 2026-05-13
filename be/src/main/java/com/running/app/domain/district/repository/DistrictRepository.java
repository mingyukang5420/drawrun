package com.running.app.domain.district.repository;

import com.running.app.domain.district.entity.District;
import java.util.List;
import java.util.Optional;
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

    // sido(시도)와 gu(구) 두 조건으로 구 하나를 찾는 메서드
    // 예: findBySidoAndGu("서울시", "송파구")
    // → SELECT * FROM districts WHERE sido = '서울시' AND gu = '송파구'
    Optional<District> findBySidoAndGu(String sido, String gu);
}