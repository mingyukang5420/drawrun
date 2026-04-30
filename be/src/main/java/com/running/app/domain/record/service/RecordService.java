package com.running.app.domain.record.service;

import com.running.app.domain.record.converter.RecordConverter;
import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.record.type.RecordStatsPeriod;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.service.TrackService;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) //읽기 전용 처리
public class RecordService {

    private final RunningRecordRepository runningRecordRepository;
    private final TrackService trackService;

    //작성
    @Transactional
    public void createRecord(
            Long memberId,
            RecordRequest.CreateDTO request
    ) {
        Track track = trackService.createTrack(
                request.getNodes(),
                request.getDistance(),
                request.getTrackImageUrl()
        );

        RunningRecord runningRecord = RecordConverter.toRunningRecord(
                memberId,
                track,
                request
        );

        runningRecordRepository.save(runningRecord);

    }

    public RecordResponse.ListResultDTO getRecordList(
            Long memberId,
            Integer page,
            Integer size
    ) {
        Pageable pageable = PageRequest.of(page, size);

        Slice<RunningRecord> recordSlice = runningRecordRepository
                .findAllByMemberIdOrderByStartedAtDesc(memberId, pageable);

        List<RecordResponse.ListDTO> content = recordSlice.getContent()
                .stream()
                .map(RecordConverter::toListDTO)
                .toList();

        return RecordConverter.toListResultDTO(
                content,
                recordSlice.getNumber(),
                recordSlice.getSize(),
                recordSlice.hasNext()
        );
    }

    public RecordResponse.DetailDTO getRecordDetail(
            Long memberId,
            Long recordId
    ) {
        RunningRecord runningRecord = runningRecordRepository.findByIdAndMemberId(
                recordId,
                memberId
        ).orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        return RecordConverter.toDetailDTO(runningRecord);
    }

    //runningRecord가 영속 상태이기에 값이 바뀌면 트랜잭션이 끝날 때 JPA가 자동으로 감지해서 업데이트
    //save() 할 필요 없음 -> dirty checking
    @Transactional
    public void changeRecordTitle(
            Long memberId,
            Long recordId,
            RecordRequest.ChangeTitleDTO request
    ) {
        RunningRecord runningRecord = runningRecordRepository.findByIdAndMemberId(
                recordId,
                memberId
        ).orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        runningRecord.changeTitle(request.getTitle());
    }

    public RecordResponse.StatsDTO getRecordStats(Long memberId, String period) {

        RecordStatsPeriod statsPeriod = RecordStatsPeriod.from(period);
        LocalDate today = LocalDate.now();

        DateRange dateRange = getDateRange(statsPeriod, today);

        List<RunningRecord> records = runningRecordRepository
                .findAllByMemberIdAndStartedAtGreaterTahnEqualAndStartedAtLessThan(
                        memberId,
                        dateRange.startAt(),
                        dateRange.endAt()
                );

        Double totalDistance = calculateTotalDistance(records);
        Integer totalCount = records.size();
        Integer totalRunningTime = calculateTotalRunningTime(records);

        String avgPace = formatAvgPaceByTotal(
                totalRunningTime,
                totalDistance
        );
        String totalTime = formatTotalTime(totalRunningTime);
        String periodLabel = getPeriodLabel(
                statsPeriod,
                dateRange,
                today,
                records
        );
        List<RecordResponse.ChartDTO> chart = createChart(
                statsPeriod,
                dateRange,
                records
        );

        return RecordConverter.toStatsDTO(
                totalDistance,
                totalCount,
                avgPace,
                totalTime,
                periodLabel,
                chart
        );
    }

    private record DateRange(
            LocalDateTime starAt,
            LocalDateTime endAt
    ){}

    private DateRange getDateRange(
            RecordStatsPeriod period,
            LocalDate today
    ) {
        return switch (period) {
            case WEEK -> getWeekRange(today);
            case MONTH -> getMonthRange(today);
            case YEAR -> getYearRange(today);
            case ALL -> getAllRange(today);
        };
    }

    private DateRange getWeekRange(LocalDate today){
        LocalDate startDate = today.with(DayOfWeek.MONDAY);
        LocalDate endDate = startDate.plusDays(7);

        return new DateRange(
                startDate.atStartOfDay(),
                endDate.atStartOfDay()
        );
    }

    private DateRange getMonthRange(LocalDate today) {
        YearMonth yearMonth = YearMonth.from(today);

        return new DateRange(
                yearMonth.atDay(1).atStartOfDay(),
                yearMonth.plusMonths(1).atDay(1).atStartOfDay
        );
    }

    private DateRange getYearRange(LocalDate today) {
        LocalDate startDate = LocalDate.of(today.getYear(), 1, 1);
        LocalDate endDate = LocalDate.of(today.getYear() + 1, 1, 1);

        return new DateRange(
                startDate.atStartOfDay(),
                endDate.atStartOfDay()
        );
    }

    private DateRange getAllRange(LocalDate today) {
        return new DateRange(
                LocalDate.of(1970,1,1).atStartOfDay(),
                today.plusDays(1).atStartOfDay()
        );
    }

    private Double calculateTotalDistance(List<RunningRecord> records) {
        return records.stream()
                .mapToDouble(record -> record.getTrack().getDistance())
                .sum();
    }

    private Integer calculateTotalRunningTime(List<RunningRecord> records) {
        return records.stream()
                .mapToInt(RunningRecord::getRunningTime)
                .sum();
    }
}

