package com.running.app.domain.record.service;

import com.running.app.domain.record.converter.RecordConverter;
import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.record.type.RecordStatsPeriod;
import com.running.app.domain.recordstats.service.MemberRecordStatsService;
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
    private final MemberRecordStatsService memberRecordStatsService;

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

        RunningRecord savedRunningRecord = runningRecordRepository.save(runningRecord);

        // 통계 테이블에 해당 기록의 데이터 합산해서 저장
        memberRecordStatsService.increaseStats(savedRunningRecord);

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

}

