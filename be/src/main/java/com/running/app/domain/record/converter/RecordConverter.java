package com.running.app.domain.record.converter;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.entity.Track;

import java.time.LocalDateTime;
import java.util.List;

public class RecordConverter {

    public static RunningRecord toRunningRecord(
            Long memberId,
            Track track,
            Boolean isCompleted,
            Boolean isSafe,
            RecordRequest.CreateDTO request
    ) {
        return RunningRecord.builder()
                .memberId(memberId)
                .courseId(request.getCourseId())
                .courseDraftId(request.getCourseDraftId())
                .track(track)
                .runningTime(request.getRunningTime())
                .avgPace(request.getAvgPace())
                .calories(request.getCalories())
                .cadence(request.getCadence())
                .isCompleted(isCompleted)
                .isSafe(isSafe)
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
                .courseDraftId(runningRecord.getCourseDraftId())
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

    public static RecordResponse.ListDTO toListDTO(
            RunningRecord runningRecord
    ) {
        Track track = runningRecord.getTrack();

        return RecordResponse.ListDTO.builder()
                .recordId(runningRecord.getId())
                .title(runningRecord.getTitle())
                .date(formatDate(runningRecord.getStartedAt()))
                .trackImageUrl(track.getTrackImageUrl())
                .distance(track.getDistance())
                .avgPace(formatAvgPace(runningRecord.getAvgPace()))
                .runningTime(formatRunningTime(runningRecord.getRunningTime()))
                .build();
    }

    public static RecordResponse.ListResultDTO toListResultDTO(
            List<RecordResponse.ListDTO> content,
            Integer page,
            Integer size,
            Boolean hasNext
    ) {
        return RecordResponse.ListResultDTO.builder()
                .content(content)
                .page(page)
                .size(size)
                .hasNext(hasNext)
                .build();
    }

    public static RecordResponse.DetailDTO toDetailDTO(
            RunningRecord runningRecord
    ) {
        Track track = runningRecord.getTrack();

        return RecordResponse.DetailDTO.builder()
                .recordId(runningRecord.getId())
                .trackId(track.getTrackId())
                .courseId(runningRecord.getCourseId())
                .courseDraftId(runningRecord.getCourseDraftId())
                .title(runningRecord.getTitle())
                .date(formatDate(runningRecord.getStartedAt()))
                .trackImageUrl(track.getTrackImageUrl())
                .distance(track.getDistance())
                .avgPace(formatAvgPace(runningRecord.getAvgPace()))
                .runningTime(formatRunningTime(runningRecord.getRunningTime()))
                .calories(runningRecord.getCalories())
                .cadence(runningRecord.getCadence())
                .isCompleted(runningRecord.getIsCompleted())
                .isSafe(runningRecord.getIsSafe())
                .nodes(TrackConverter.toNodeDTOList(track))
                .build();
    }

    public static RecordResponse.StatsDTO toStatsDTO(
            Double totalDistance,
            Integer totalCount,
            String avgPace,
            String totalTime,
            String periodLabel,
            List<RecordResponse.ChartDTO> chart
    ) {
        return RecordResponse.StatsDTO.builder()
                .totalDistance(totalDistance)
                .totalCount(totalCount)
                .avgPace(avgPace)
                .totalTime(totalTime)
                .periodLabel(periodLabel)
                .chart(chart)
                .build();
    }

    public static RecordResponse.ChartDTO toChartDTO(
            String label,
            Double distance
    ) {
        return RecordResponse.ChartDTO.builder()
                .label(label)
                .distance(distance)
                .build();
    }

    //---------------------------------------------

    // [2026.04.22] 형식으로 변환
    private static String formatDate(LocalDateTime startedAt) {
        return String.format(
                "%d. %d. %d.",
                startedAt.getYear(),
                startedAt.getMonthValue(),
                startedAt.getDayOfMonth()
        );
    }

    // [7'08''] 형식으로 변환
    private static String formatAvgPace(Double avgPace) {
        int totalSeconds = (int) Math.round(avgPace * 60);
        int minutes = totalSeconds / 60;
        int seconds = totalSeconds % 60;

        return String.format("%d'%02d''", minutes, seconds);
    }

    // [21:26] 형식으로 변환
    private static String formatRunningTime(Integer runningTime) {
        int minutes = runningTime / 60;
        int seconds = runningTime % 60;

        return String.format("%02d:%02d", minutes, seconds);
    }

}


