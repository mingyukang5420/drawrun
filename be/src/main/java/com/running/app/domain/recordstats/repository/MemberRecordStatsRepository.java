package com.running.app.domain.recordstats.repository;

import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

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
}