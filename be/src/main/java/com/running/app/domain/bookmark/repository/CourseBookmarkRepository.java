package com.running.app.domain.bookmark.repository;

import com.running.app.domain.bookmark.entity.CourseBookmark;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface CourseBookmarkRepository extends JpaRepository<CourseBookmark, Long> {

    // 이미 존재하는지 체크
    boolean existsByMemberIdAndCourse_Id(Long memberId, Long courseId);

    Optional<CourseBookmark> findByMemberIdAndCourse_Id(Long memberId, Long courseId);

    void deleteByMemberIdAndCourse_Id(Long memberId, Long courseId);

    // 북마크 목록 조회용
    @Query("""
            select cb
            from CourseBookmark cb
            join fetch cb.course c
            join fetch c.sourceRecord sr
            join fetch sr.track t
            where cb.memberId = :memberId
            order by cb.createdAt desc
            """)
    Slice<CourseBookmark> findMyBookmarkSlice(
            Long memberId,
            Pageable pageable
    );

    // 내 북마크 개수 조회
    Integer countByMemberId(Long memberId);
}
