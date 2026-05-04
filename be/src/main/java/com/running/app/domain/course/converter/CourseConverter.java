package com.running.app.domain.course.converter;

import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.track.entity.Track;
import java.time.LocalDateTime;
import java.util.List;

import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.entity.Track;
import org.springframework.data.domain.Slice;

public abstract class CourseConverter {

    // 에디터 저장용 — record_id / registered_at 은 null, completion_score 는 0 으로 시작
    public static Course toCourseFromEditor(
            Long memberId,
            Track track,
            String title,
            CourseDifficulty difficulty
    ) {
        return Course.builder()
                .memberId(memberId)
                .track(track)
                .title(title)
                .difficulty(difficulty)
                .completionScore(0)
                .build();
    }

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

    public static CourseResponse.CourseDetailDTO toDetailDTO(
            Course course,
            List<String> regions,
            Boolean isCompleted
    ) {
        Track track = course.getTrack();

        return CourseResponse.CourseDetailDTO.builder()
                .courseId(course.getId())
                .title(course.getTitle())
                .difficulty(course.getDifficulty().name())
                .regions(regions)
                .completionScore(course.getCompletionScore())
                .thumbnailUrl(track.getTrackImageUrl())
                .distance(track.getDistance())
                .isCompleted(isCompleted)
                .createdAt(formatDate(course.getRegisteredAt()))
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