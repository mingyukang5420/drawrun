package com.running.app.domain.record.repository;

import com.running.app.domain.challenge.projection.ChallengeParticipationQueryResult;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.projection.ChallengeRankingQueryResult;
import com.running.app.domain.record.projection.RankingQueryResult;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

//우선은 기본 JpsRepository로 생성
//다음 페이지가 있는지만 확인하고 로드
public interface RunningRecordRepository extends JpaRepository<RunningRecord, Long> {

    // 무한스크롤 용 슬라이드 조회
    //fetch join을 적용해 한번의 select 쿼리로 track 정보까지 조회
    @EntityGraph(attributePaths = {"track"})
    Slice<RunningRecord> findAllByMemberIdOrderByStartedAtDesc(
            Long memberId,
            Pageable pageable
    );

    // 조회 결과가 없을 경우 던지기 위한 Optional 반환 타입 사용
    @EntityGraph(attributePaths = {"track"})
    Optional<RunningRecord> findByIdAndMemberId(
            Long recordId,
            Long memberId
    );

    @EntityGraph(attributePaths = {"track"})
    List<RunningRecord> findAllByMemberIdAndStartedAtGreaterThanEqualAndStartedAtLessThan(
            Long memberId,
            LocalDateTime startAt,
            LocalDateTime endAt
    );

    // 로그인한 사용자가 완주한 코스 목록
    @Query("""
            select distinct r.courseId
            from RunningRecord r
            where r.memberId = :memberId
              and r.courseId in :courseIds
              and r.isCompleted = true
            """)
    List<Long> findCompletedCourseIds(
            Long memberId,
            List<Long> courseIds
    );

    // 전체 코스 횟수 조회
    Integer countByCourseId(Long courseId);

    // 완주한 코스 횟수 조회
    Integer countByCourseIdAndIsCompletedTrue(Long courseId);

    // 로그인한 사용자가 이 코스를 완주했는지 확인
    Boolean existsByMemberIdAndCourseIdAndIsCompletedTrue(
            Long memberId,
            Long CourseId
    );

    // Track 미참조 여부 확인 — 에디터 임시 저장본 삭제 시 Track 동반 삭제 가능 여부 판단용
    boolean existsByTrack_TrackId(Long trackId);

    // 조회하려는 코스에서 사용자 별 최고기록만을 오름차순(완주 기록 빠른 순)으로 가져옴
    @Query("""
            SELECT r.memberId AS memberId, MIN(r.runningTime) AS bestTime
            FROM RunningRecord r
            WHERE r.courseId = :courseId AND r.isCompleted = true
            GROUP BY r.memberId
            order by MIN(r.runningTime) ASC
            """)
    List<RankingQueryResult> findRankingByCourseId(@Param("courseId") Long courseId);

    // 내 기록 개수 조회
    Integer countByMemberId(Long memberId);

    // 챌린지 참가 기록에서 사용자 별 최고 유사도를 내림차순(유사도 높은 순)으로 가져옴
    @Query("""
            SELECT r.memberId AS memberId, MAX(r.similarityScore) AS bestSimilarityScore
            FROM RunningRecord r
            WHERE r.challengeId = :challengeId
            AND r.similarityScore IS NOT NULL
            GROUP BY r.memberId
            ORDER BY MAX(r.similarityScore) DESC
            """)
    List<ChallengeRankingQueryResult> findRankingByChallengeId(
            @Param("challengeId") Long challengeId);

    // 챌린지별 총 참여자 수 조회
    @Query("""
              SELECT COUNT(DISTINCT r.memberId)
              FROM RunningRecord r
              WHERE r.challengeId = :challengeId
              AND r.similarityScore IS NOT NULL
            """)
    Integer countParticipantsByChallengeId(@Param("challengeId") Long challengeId);


    // 내 챌린지 최고 유사도 기록 1개 조회 (track JOIN 포함)
    @EntityGraph(attributePaths = {"track"})
    Optional<RunningRecord> findTopByMemberIdAndChallengeIdOrderBySimilarityScoreDesc(
            Long memberId, Long challengeId
    );

    @Query("""
              SELECT c.id AS challengeId,
                     c.title AS title,
                     c.difficulty AS difficulty
              FROM RunningRecord r
              JOIN Challenge c ON r.challengeId = c.id
              WHERE r.memberId = :memberId
              AND r.challengeId IS NOT NULL
              GROUP BY c.id, c.title, c.difficulty 
              ORDER BY c.title ASC, c.id ASC
            """)
    List<ChallengeParticipationQueryResult> findParticipatedChallengesByMemberId(
            @Param("memberId") Long memberId
    );

    // CourseDraft의 id 묶음과 member의 id를 받아 courseDrat 묶음들의 모든 record값을 가져옴
    List<RunningRecord> findByMemberIdAndCourseDraftIdIn(Long memberId, List<Long> courseDraftIds);

}
