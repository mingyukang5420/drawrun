package com.running.app.domain.recordstats.service;

import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.recordstats.converter.MemberRecordStatsConverter;
import com.running.app.domain.recordstats.entity.MemberRecordStats;
import com.running.app.domain.recordstats.repository.MemberRecordStatsRepository;
import com.running.app.domain.recordstats.type.RecordStatsPeriodType;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberRecordStatsService {

    private static final DateTimeFormatter DAY_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd");
    private static final DateTimeFormatter MONTH_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM");

    private static final String ALL_PERIOD_KEY = "ALL";

    private final MemberRecordStatsRepository memberRecordStatsRepository;

    @Transactional
    public void increaseStats(
            RunningRecord runningRecord
    ) {
        Long memberId = runningRecord.getMemberId();
        LocalDate runningDate = runningRecord.getStartedAt().toLocalDate();
        Double distance = runningRecord.getTrack().getDistance();
        Integer runningTime = runningRecord.getRunningTime();

        increaseStatsByPeriod(
                memberId,
                RecordStatsPeriodType.DAY,
                runningDate.format(DAY_FORMATTER),
                distance,
                runningTime
        );

        increaseStatsByPeriod(
                memberId,
                RecordStatsPeriodType.MONTH,
                runningDate.format(MONTH_FORMATTER),
                distance,
                runningTime
        );

        increaseStatsByPeriod(
                memberId,
                RecordStatsPeriodType.YEAR,
                String.valueOf(runningDate.getYear()),
                distance,
                runningTime
        );

        increaseStatsByPeriod(
                memberId,
                RecordStatsPeriodType.ALL,
                ALL_PERIOD_KEY,
                distance,
                runningTime
        );
    }

    private void increaseStatsByPeriod(
            Long memberId,
            RecordStatsPeriodType periodType,
            String periodKey,
            Double distance,
            Integer runningTime
    ) {
        memberRecordStatsRepository.upsertStats(
                memberId,
                periodType.name(),
                periodKey,
                distance,
                runningTime
        );
    }
}