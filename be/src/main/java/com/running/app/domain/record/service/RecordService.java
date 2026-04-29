package com.running.app.domain.record.service;

import com.running.app.domain.record.converter.RecordConverter;
import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.service.TrackService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

}

