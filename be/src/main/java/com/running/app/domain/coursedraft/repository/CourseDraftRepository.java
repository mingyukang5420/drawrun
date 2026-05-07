package com.running.app.domain.coursedraft.repository;

import com.running.app.domain.coursedraft.dto.CourseDraftListItem;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.type.CourseDraftStatus;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CourseDraftRepository extends JpaRepository<CourseDraft, Long> {

    Optional<CourseDraft> findByIdAndMemberId(Long id, Long memberId);

    // [ALL] 사용자의 모든 드래프트 — 상태 무관.
    // courses 와의 JOIN 이 불필요하므로 courseId 는 null 로 고정.
    @Query("""
            select cd.id as courseDraftId,
                   cast(null as java.lang.Long) as courseId,
                   cd.title as title,
                   cd.difficulty as difficulty,
                   cd.status as status,
                   t.distance as distance,
                   t.trackImageUrl as trackImageUrl,
                   cd.createdAt as createdAt
            from CourseDraft cd
                left join cd.track t
            where cd.memberId = :memberId
            order by cd.createdAt desc
            """)
    Slice<CourseDraftListItem> findAllByMemberId(
            @Param("memberId") Long memberId,
            Pageable pageable
    );

    // [READY/DONE] 상태 단일 매칭. 인덱스(member_id, status) 활용 의도가 명확하도록 분리.
    @Query("""
            select cd.id as courseDraftId,
                   cast(null as java.lang.Long) as courseId,
                   cd.title as title,
                   cd.difficulty as difficulty,
                   cd.status as status,
                   t.distance as distance,
                   t.trackImageUrl as trackImageUrl,
                   cd.createdAt as createdAt
            from CourseDraft cd
                left join cd.track t
            where cd.memberId = :memberId
              and cd.status = :status
            order by cd.createdAt desc
            """)
    Slice<CourseDraftListItem> findAllByMemberIdAndStatus(
            @Param("memberId") Long memberId,
            @Param("status") CourseDraftStatus status,
            Pageable pageable
    );

    // [REGISTERED] course_drafts → records → courses 체인이 형성된 행만.
    // CourseDraft 엔티티에 records, courses 와의 연관관계 매핑이 없으므로 native 로 작성.
    @Query(
            nativeQuery = true,
            value = """
                    SELECT cd.course_draft_id   AS courseDraftId,
                           c.course_id           AS courseId,
                           cd.title              AS title,
                           cd.difficulty         AS difficulty,
                           cd.status             AS status,
                           t.distance            AS distance,
                           t.track_image_url     AS trackImageUrl,
                           cd.created_at         AS createdAt
                    FROM course_drafts cd
                        LEFT JOIN tracks   t ON t.track_id          = cd.track_id
                        LEFT JOIN records  r ON r.course_draft_id   = cd.course_draft_id
                        LEFT JOIN courses  c ON c.source_record_id  = r.record_id
                    WHERE cd.member_id = :memberId
                      AND c.course_id IS NOT NULL
                    ORDER BY cd.created_at DESC
                    """
    )
    Slice<CourseDraftListItem> findRegisteredByMemberId(
            @Param("memberId") Long memberId,
            Pageable pageable
    );
}
