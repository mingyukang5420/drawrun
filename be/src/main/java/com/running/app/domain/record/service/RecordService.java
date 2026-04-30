package com.running.app.domain.record.service;

import com.running.app.domain.record.converter.RecordConverter;
import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
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

}

