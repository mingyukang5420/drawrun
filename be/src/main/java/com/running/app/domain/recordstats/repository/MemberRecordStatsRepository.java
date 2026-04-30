package com.running.app.domain.recordstats.repository;

import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MemberRecordStatsRepository extends JpaRepository<MemberRecordStats, Long> {

    // 사용자의 특정 기간 통계 row 찾기
    Optional<MemberRecordStats> findByMemberIdAndPeriodTypeAndPeriodKey(
            Long memberId,
            RecordStatsPeriodType periodType,
            String periodKey
    );

    // 기간 범위 조회 메서드
    List<MemberRecordStats> findAllByMemberIdAndPeriodTypeAndPeriodKeyBetweenOrderByPeriodKeyAsc(
            Long memberId,
            RecordStatsPeriodType periodType,
            String startKey,
            String endKey
    );

    // 특정 타입 전체 조회 메서드 (all)
    List<MemberRecordStats> findAllByMemberIdAndPeriodTypeOrderByPeriodKeyAsc(
            Long memberId,
            RecordStatsPeriodType periodType
    );

    @Modifying
    @Query(
            value = """
                INSERT INTO member_record_stats (
                    member_id,
                    period_type,
                    period_key,
                    total_distance,
                    total_count,
                    total_running_time,
                    created_at,
                    updated_at
                )
                VALUES (
                    :memberId,
                    :periodType,
                    :periodKey,
                    :distance,
                    1,
                    :runningTime,
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (member_id, period_type, period_key)
                DO UPDATE SET
                    total_distance = member_record_stats.total_distance + EXCLUDED.total_distance,
                    total_count = member_record_stats.total_count + EXCLUDED.total_count,
                    total_running_time = member_record_stats.total_running_time + EXCLUDED.total_running_time,
                    updated_at = CURRENT_TIMESTAMP
                """,
            nativeQuery = true
    )
    // insert + update
    // 데이터가 없으면 새로 넣고, 이미 있으면 기존 데이터를 수정
    void upsertStats(
            @Param("memberId") Long memberId,
            @Param("periodType") String periodType,
            @Param("periodKey") String periodKey,
            @Param("distance") Double distance,
            @Param("runningTime") Integer runningTime
    );
}