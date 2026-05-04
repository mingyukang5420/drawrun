package com.running.app.domain.course.repository;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.type.CourseDifficulty;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CourseRepository extends JpaRepository<Course, Long> {
    
    // 정상 코스 조회
    @EntityGraph(attributePaths = {"track"})
    Slice<Course> findAllByDeletedAtIsNullAndRegisteredAtIsNotNull(
            Pageable pageable
    );

    // 난이도 필터 조회
    @EntityGraph(attributePaths = {"track"})
    Slice<Course> findAllByDeletedAtIsNullAndRegisteredAtIsNotNullAndDifficulty(
            CourseDifficulty difficulty,
            Pageable pageable
    );
}