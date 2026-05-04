package com.running.app.domain.course.converter;

import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Slice;

public abstract class CourseConverter {

    public static CourseResponse.CourseListDTO toListDTO(
            Course course,
            List<String> regions,
            Boolean isCompleted
    ) {
        return CourseResponse.CourseListDTO.builder()
                .courseId(course.getId())
                .title(course.getTitle())
                .difficulty(course.getDifficulty().name())
                .distance(course.getTrack().getDistance())
                .regions(regions)
                .isCompleted(isCompleted)
                .thumbnailUrl(course.getTrack().getTrackImageUrl())
                .createdAt(formatDate(course.getRegisteredAt()))
                .completionScore(course.getCompletionScore())
                .build();
    }

    public static CourseResponse.CourseListResultDTO toListResultDTO(
            Slice<Course> courseSlice,
            List<CourseResponse.CourseListDTO> content
    ) {
        return CourseResponse.CourseListResultDTO.builder()
                .content(content)
                .page(courseSlice.getNumber())
                .size(courseSlice.getSize())
                .hasNext(courseSlice.hasNext())
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