package com.running.app.domain.course.repository;

import com.running.app.domain.course.entity.CourseDistrict;
import java.util.List;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CourseDistrictRepository extends JpaRepository<CourseDistrict, Long> {

    // 코스에 연결된 지역들 조회 (상세 조회용)
    @EntityGraph(attributePaths = {"district"})
    List<CourseDistrict> findAllByCourse_Id(Long courseId);

    // 코스 ID로 지역 정보 한번에 조회 (목록 조회용)
    @EntityGraph(attributePaths = {"district"})
    List<CourseDistrict> findAllByCourse_IdIn(List<Long> courseIds);

    // Course 삭제 전 자식 행 정리용 — course_district.course_id FK 위반 방지
    void deleteByCourseId(Long courseId);
}