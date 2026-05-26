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
            join fetch c.sourceRecord sr
            join fetch sr.track t
            where c.deletedAt is null
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
            join fetch c.sourceRecord sr
            join fetch sr.track t
            where c.deletedAt is null
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
    @Query("""
            select c
            from Course c
            join fetch c.sourceRecord sr
            join fetch sr.track
            where c.id = :courseId
              and c.deletedAt is null
            """)
    Optional<Course> findByIdWithTrack(Long courseId);

    Optional<Course> findByIdAndMemberIdAndDeletedAtIsNull(Long id, Long memberId);

    boolean existsBySourceRecord_Id(Long sourceRecordId);

    @Query("""
            select c
            from Course c
            join fetch c.sourceRecord sr
            join fetch sr.track t
            where c.deletedAt is null
                and lower(c.title) like lower(concat('%', :keyword, '%'))
            """)
    Slice<Course> searchCourseSlice(String keyword, Pageable pageable);

    // 마이코스 목록 조회
    @Query("""
            select c
            from Course c
            join fetch c.sourceRecord sr
            join fetch sr.track t
            where c.memberId = :memberId
              and c.deletedAt is null
            """)
    Slice<Course> findMyCourseSlice(
            Long memberId,
            Pageable pageable
    );

    // 마이코스 상세 조회
    @Query("""
            select c
            from Course c
            join fetch c.sourceRecord sr
            join fetch sr.track
            where c.id = :courseId
              and c.memberId = :memberId
              and c.deletedAt is null
            """)
    Optional<Course> findMyCourseByIdWithTrack(
            Long memberId,
            Long courseId
    );

    // 내가 등록한 코스 개수 조회
    Integer countByMemberIdAndDeletedAtIsNull(Long memberId);

}
