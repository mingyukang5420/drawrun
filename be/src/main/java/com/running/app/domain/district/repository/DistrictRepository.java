package com.running.app.domain.district.repository;

import com.running.app.domain.district.entity.District;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface DistrictRepository extends JpaRepository<District, String> {

    List<District> findAllByGuIn(List<String> guList);
    
    Optional<District> findByGu(String gu);
}