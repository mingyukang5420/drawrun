package com.running.app.domain.course.converter;

import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.entity.Track;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Slice;

public abstract class CourseConverter {

    public static Course toCourseFromRecord(
            Long memberId,
            RunningRecord sourceRecord,
            CourseDifficulty difficulty
    ) {
        return Course.builder()
                .memberId(memberId)
                .sourceRecord(sourceRecord)
                .title(sourceRecord.getTitle())
                .difficulty(difficulty)
                .completionScore(0)
                .build();
    }

    public static CourseResponse.CourseListDTO toListDTO(
            Course course,
            List<String> regions,
            Boolean isCompleted
    ) {
        Track track = course.getSourceRecord().getTrack();

        return CourseResponse.CourseListDTO.builder()
                .courseId(course.getId())
                .title(course.getTitle())
                .difficulty(course.getDifficulty().name())
                .distance(track.getDistance())
                .regions(regions)
                .isCompleted(isCompleted)
                .thumbnailUrl(track.getTrackImageUrl())
                .createdAt(formatDate(course.getCreatedAt()))
                .completionScore(course.getCompletionScore())
                .build();
    }

    public static CourseResponse.CourseListResultDTO toListResultDTO(
            Slice<?> courseSlice,
            List<CourseResponse.CourseListDTO> content
    ) {
        return CourseResponse.CourseListResultDTO.builder()
                .content(content)
                .page(courseSlice.getNumber())
                .size(courseSlice.getSize())
                .hasNext(courseSlice.hasNext())
                .build();
    }

    public static CourseResponse.CourseDetailDTO toDetailDTO(
            Course course,
            List<String> regions,
            Boolean isCompleted
    ) {
        Track track = course.getSourceRecord().getTrack();

        return CourseResponse.CourseDetailDTO.builder()
                .courseId(course.getId())
                .title(course.getTitle())
                .difficulty(course.getDifficulty().name())
                .regions(regions)
                .completionScore(course.getCompletionScore())
                .thumbnailUrl(track.getTrackImageUrl())
                .distance(track.getDistance())
                .isCompleted(isCompleted)
                .createdAt(formatDate(course.getCreatedAt()))
                .nodes(TrackConverter.toNodeDTOList(track))
                .build();

    }

    private static String formatDate(LocalDateTime dateTime) {
        if (dateTime == null) {
            return null;
        }

        return String.format(
                "%d-%02d-%02d",
                dateTime.getYear(),
                dateTime.getMonthValue(),
                dateTime.getDayOfMonth()
        );
    }
}