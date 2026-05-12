package com.running.app.domain.course.controller;

import com.running.app.domain.course.dto.CourseRequest;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.service.CourseService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/member/mycourse")
@Tag(name = "MyCourse", description = "마이코스 API")
public class MyCourseController {

    private final CourseService courseService;

    @Operation(summary = "마이코스 목록 조회")
    @GetMapping
    public ApiResponse<CourseResponse.CourseListResultDTO> getMyCourseList(
            @AuthenticationPrincipal String loginId,
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size
    ) {
        CourseResponse.CourseListResultDTO response = courseService.getMyCourseList(
                loginId,
                page,
                size
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(summary = "마이코스 상세 조회")
    @GetMapping("/{courseId}")
    public ApiResponse<CourseResponse.CourseDetailDTO> getMyCourse(
            @AuthenticationPrincipal String loginId,
            @PathVariable Long courseId
    ) {
        CourseResponse.CourseDetailDTO response = courseService.getMyCourse(
                loginId,
                courseId
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(summary = "마이코스 제목 수정")
    @PatchMapping("/{courseId}")
    public ApiResponse<Void> changeMyCourseTitle(
            @AuthenticationPrincipal String loginId,
            @PathVariable Long courseId,
            @Valid @RequestBody CourseRequest.ChangeTitleDTO request
    ) {
        courseService.changeCourseTitle(loginId, courseId, request);

        return ApiResponse.OK;
    }
}
