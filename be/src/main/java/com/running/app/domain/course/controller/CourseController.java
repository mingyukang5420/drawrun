package com.running.app.domain.course.controller;

import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.service.CourseService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Course", description = "코스 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/course")
public class CourseController {

    private final CourseService courseService;

    @Operation(
            summary = "코스 목록 조회",
            description = """
                    등록된 코스 목록을 조회.

                    조회 조건:
                    - page: 페이지 번호, 기본값 0
                    - size: 페이지 크기, 기본값 10
                    - difficulty: 난이도 필터, BEGINNER/EASY/NORMAL/HARD
                    - sort: 정렬 기준, latest/completionScore
                    """
    )
    @GetMapping
    public ApiResponse<CourseResponse.CourseListResultDTO> getCourseList(
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size,
            @RequestParam(name = "difficulty", required = false) String difficulty,
            @RequestParam(name = "sort", defaultValue = "latest") String sort
    ) {
        Long memberId = 1L;

        CourseResponse.CourseListResultDTO response = courseService.getCourseList(
                memberId,
                page,
                size,
                difficulty,
                sort
        );

        return ApiResponse.onSuccess(response);
    }
}