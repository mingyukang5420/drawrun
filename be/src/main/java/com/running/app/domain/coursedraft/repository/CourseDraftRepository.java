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

    // challengeId에 맞는 요청한 사용자의 courseDraft 목록을 불러옴
    @Query("""
            select cd
            from CourseDraft cd
                join fetch cd.track t
            where cd.memberId = :memberId
                and cd.challenge.id = :challengeId
            order by cd.createdAt desc
            """)
    Slice<CourseDraft> findAllByMemberIdWithChallengeId(
            @Param("memberId") Long memberId,
            @Param("challengeId") Long challengeId,
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

    // [DONE] status=DONE 이지만 아직 정식 코스로 등록되지 않은 드래프트만.
    // 한 draft 에 records 가 여러 건 매달릴 수 있으므로 LEFT JOIN + IS NULL 대신 NOT EXISTS 로
    // cardinality 영향 없이 "등록된 record 가 0개" 를 검증. CourseDraft 엔티티에 records/courses
    // 매핑이 없으므로 native 로 작성.
    @Query(
            nativeQuery = true,
            value = """
                    SELECT cd.course_draft_id   AS courseDraftId,
                           NULL                  AS courseId,
                           cd.title              AS title,
                           cd.difficulty         AS difficulty,
                           cd.status             AS status,
                           t.distance            AS distance,
                           t.track_image_url     AS trackImageUrl,
                           cd.created_at         AS createdAt
                    FROM course_drafts cd
                        LEFT JOIN tracks t ON t.track_id = cd.track_id
                    WHERE cd.member_id = :memberId
                      AND cd.status = 'DONE'
                      AND NOT EXISTS (
                          SELECT 1
                          FROM records r
                              JOIN courses c ON c.source_record_id = r.record_id
                          WHERE r.course_draft_id = cd.course_draft_id
                            AND c.deleted_at IS NULL
                      )
                    ORDER BY cd.created_at DESC
                    """
    )
    Slice<CourseDraftListItem> findUnregisteredDoneByMemberId(
            @Param("memberId") Long memberId,
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
                      AND c.deleted_at IS NULL
                    ORDER BY cd.created_at DESC
                    """
    )
    Slice<CourseDraftListItem> findRegisteredByMemberId(
            @Param("memberId") Long memberId,
            Pageable pageable
    );

    // 상세 조회 시 status derived 용. 이 draft 를 source 로 한 record 가
    // 정식 코스로(soft delete 되지 않은 상태로) 등록되어 있는지 검사.
    @Query(
            nativeQuery = true,
            value = """
                    SELECT EXISTS (
                        SELECT 1
                        FROM records r
                            JOIN courses c ON c.source_record_id = r.record_id
                        WHERE r.course_draft_id = :courseDraftId
                          AND c.deleted_at IS NULL
                    )
                    """
    )
    boolean existsRegisteredCourseByDraftId(@Param("courseDraftId") Long courseDraftId);
}
