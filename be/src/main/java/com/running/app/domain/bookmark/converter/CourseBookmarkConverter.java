package com.running.app.domain.bookmark.converter;

import com.running.app.domain.bookmark.entity.CourseBookmark;
import com.running.app.domain.course.entity.Course;

public class CourseBookmarkConverter {

    public static CourseBookmark toCourseBookmark(
            Long memberId,
            Course course
    ) {
        return CourseBookmark.builder()
                .memberId(memberId)
                .course(course)
                .build();
    }
}
