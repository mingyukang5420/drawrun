package com.running.app.domain.bookmark.controller;

import com.running.app.domain.bookmark.service.CourseBookmarkService;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Course Bookmark", description = "코스 북마크 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1")
public class CourseBookmarkController {

    private final CourseBookmarkService courseBookmarkService;

    @Operation(summary = "코스 북마크 추가")
    @PostMapping("/course/{courseId}/bookmark")
    public ApiResponse<Void> addBookmark(
            @AuthenticationPrincipal String loginId,
            @PathVariable Long courseId
    ) {
        courseBookmarkService.addBookmark(loginId, courseId);

        return ApiResponse.OK;
    }

    @Operation(summary = "코스 북마크 제거")
    @DeleteMapping("/course/{courseId}/bookmark")
    public ApiResponse<Void> removeBookmark(
            @AuthenticationPrincipal String loginId,
            @PathVariable Long courseId
    ) {
        courseBookmarkService.removeBookmark(loginId, courseId);
        return ApiResponse.OK;
    }

    @Operation(summary = "내 북마크 코스 목록 조회")
    @GetMapping("/member/bookmark/course")
    public ApiResponse<CourseResponse.CourseListResultDTO> getMyBookmarkedCourses(
            @AuthenticationPrincipal String loginId,
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size
    ) {
        CourseResponse.CourseListResultDTO response = courseBookmarkService.getMyBookmarkedCourses(loginId, page, size);

        return ApiResponse.onSuccess(response);
    }
}
