package com.running.app.domain.course.repository;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.type.CourseDifficulty;
import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface CourseRepository extends JpaRepository<Course, Long> {
    
    // 지역 없을 때 코스 조회 (빈 리스트 넣었을 시 발생할 수 있는 오류 방지)
    @Query("""
            select c
            from Course c
            join fetch c.track t
            where c.deletedAt is null
              and c.registeredAt is not null
              and (:difficulty is null or c.difficulty = :difficulty)
              and (:minDistance is null or t.distance >= :minDistance)
              and (:maxDistance is null or t.distance <= :maxDistance)
              and (
                    :isCompleted is null
                    or (
                        :isCompleted = true
                        and exists (
                            select 1
                            from RunningRecord r
                            where r.courseId = c.id
                              and r.memberId = :memberId
                              and r.isCompleted = true
                        )
                    )
                    or (
                        :isCompleted = false
                        and not exists (
                            select 1
                            from RunningRecord r
                            where r.courseId = c.id
                              and r.memberId = :memberId
                              and r.isCompleted = true
                        )
                    )
              )
            """)
    Slice<Course> findCourseSlice(
            Long memberId,
            CourseDifficulty difficulty,
            Double minDistance,
            Double maxDistance,
            Boolean isCompleted,
            Pageable pageable
    );

    // 지역 필터 조회
    @Query("""
            select distinct c
            from Course c
            join fetch c.track t
            where c.deletedAt is null
              and c.registeredAt is not null
              and (:difficulty is null or c.difficulty = :difficulty)
              and (:minDistance is null or t.distance >= :minDistance)
              and (:maxDistance is null or t.distance <= :maxDistance)
              and exists (
                  select 1
                  from CourseDistrict cd
                  join cd.district d
                  where cd.course = c
                    and d.gu in :regions
              )
              and (
                    :isCompleted is null
                    or (
                        :isCompleted = true
                        and exists (
                            select 1
                            from RunningRecord r
                            where r.courseId = c.id
                              and r.memberId = :memberId
                              and r.isCompleted = true
                        )
                    )
                    or (
                        :isCompleted = false
                        and not exists (
                            select 1
                            from RunningRecord r
                            where r.courseId = c.id
                              and r.memberId = :memberId
                              and r.isCompleted = true
                        )
                    )
              )
            """)
    Slice<Course> findCourseSliceByRegions(
            Long memberId,
            CourseDifficulty difficulty,
            Double minDistance,
            Double maxDistance,
            List<String> regions,
            Boolean isCompleted,
            Pageable pageable
    );

    // 코스 상세 조회 메서드
    // 연결된 track도 같이 가져온다.
    @Query("""
            select c
            from Course c
            join fetch c.track
            where c.id = :courseId
                and c.deletedAt is null
                and c.registeredAt is not null
            """)
    Optional<Course> findByIdWithTrack(Long courseId);
}