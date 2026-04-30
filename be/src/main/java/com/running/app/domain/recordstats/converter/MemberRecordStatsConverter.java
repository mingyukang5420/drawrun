package com.running.app.domain.recordstats.converter;

import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;

public abstract class MemberRecordStatsConverter {

    public static MemberRecordStats toMemberRecordStats(
            Long memberId,
            RecordStatsPeriodType periodType,
            String periodKey
    ) {
        return MemberRecordStats.builder()
                .memberId(memberId)
                .periodType(periodType)
                .periodKey(periodKey)
                .totalDistance(0.0)
                .totalCount(0)
                .totalRunningTime(0)
                .build();
    }
}