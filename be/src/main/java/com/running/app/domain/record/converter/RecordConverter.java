package com.running.app.domain.record.converter;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.track.entity.Track;

public class RecordConverter {

    public static RunningRecord toRunningRecord(
            Long memberId,
            Track track,
            RecordRequest.CreateDTO request
    ) {
        return RunningRecord.builder()
                .memberId(memberId)
                .courseId(request.getCourseId())
                .track(track)
                .runningTime(request.getRunningTime())
                .avgPace(request.getAvgPace())
                .calories(request.getCalories())
                .cadence(request.getCadence())
                .isCompleted(true) // 완주판정 임시 true 처리
                .isSafe(true) // 검증 임시 true 처리
                .title(request.getTitle())
                .startedAt(request.getStartedAt())
                .endedAt(request.getEndedAt())
                .build();
    }

    public static RecordResponse.CreateResultDTO toCreateResultDTO(
            RunningRecord runningRecord
    ) {
        Track track = runningRecord.getTrack();

        return RecordResponse.CreateResultDTO.builder()
                .recordId(runningRecord.getId())
                .trackId(track.getTrackId())
                .courseId(runningRecord.getCourseId())
                .title(runningRecord.getTitle())
                .distance(track.getDistance())
                .trackImageUrl(track.getTrackImageUrl())
                .runningTime(runningRecord.getRunningTime())
                .avgPace(runningRecord.getAvgPace())
                .calories(runningRecord.getCalories())
                .cadence(runningRecord.getCadence())
                .isCompleted(runningRecord.getIsCompleted())
                .isSafe(runningRecord.getIsSafe())
                .build();
    }

}


