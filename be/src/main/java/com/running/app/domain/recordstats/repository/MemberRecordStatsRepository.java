package com.running.app.domain.recordstats.repository;

import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MemberRecordStatsRepository extends JpaRepository<MemberRecordStats, Long> {

    // 사용자의 특정 기간 통계 row 찾기
    Optional<MemberRecordStats> findByMemberIdAndPeriodTypeAndPeriodKey(
            Long memberId,
            RecordStatsPeriodType periodType,
            String periodKey
    );
}