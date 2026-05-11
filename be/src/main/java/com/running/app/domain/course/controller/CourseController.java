package com.running.app.domain.course.controller;

import com.running.app.domain.course.dto.CourseRequest;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.service.CourseService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
                    - distance: 거리 필터
                        minDistance : 최소 거리
                        maxDistance : 최대 거리
                    - region: 지역 복수 필터
                    - isCompleted: 로그인한 사용자의 완주 여부 필터
                        true : 내가 완주한 코스만 조회
                        false : 내가 아직 완주하지 않은 코스만 조회
                        미전달 : 전체 조회
                    - sort: 정렬 기준, latest/completionScore
                    """
    )
    @GetMapping
    public ApiResponse<CourseResponse.CourseListResultDTO> getCourseList(
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size,
            @RequestParam(name = "difficulty", required = false) String difficulty,
            @RequestParam(name = "minDistance", required = false) Double minDistance,
            @RequestParam(name = "maxDistance", required = false) Double maxDistance,
            @RequestParam(name = "regions", required = false) List<String> regions,
            @RequestParam(name = "isCompleted", required = false) Boolean isCompleted,
            @RequestParam(name = "sort", defaultValue = "latest") String sort
    ) {
        Long memberId = 1L;

        CourseResponse.CourseListResultDTO response = courseService.getCourseList(
                memberId,
                page,
                size,
                difficulty,
                minDistance,
                maxDistance,
                regions,
                isCompleted,
                sort
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(summary = "기록에서 코스 생성")
    @PostMapping("/records/{recordId}")
    public ApiResponse<Long> createCourseFromRecord(
            @PathVariable Long recordId
    ) {
        Long memberId = 1L;
        Long courseId = courseService.createCourseFromRecord(memberId, recordId);
        return ApiResponse.onSuccess(courseId);
    }

    @Operation(
            summary = "코스 상세 조회",
            description = """
                    특정 코스의 상세 정보 조회
                    
                    반환 정보 :
                    - 코스 기본 정보
                    - 난이도
                    - 지역 목록
                    - 완주 점수
                    - 지도 미리보기
                    - 거리
                    - 로그인한 사용자의 완주 여부
                    - 경로 좌표 nodes
                    """
    )
    @GetMapping("/{courseId}")
    public ApiResponse<CourseResponse.CourseDetailDTO> getCourse(
            @PathVariable(name = "courseId") Long courseId
    ) {
        Long memberId = 1L;

        CourseResponse.CourseDetailDTO response = courseService.getCourse(
                memberId,
                courseId
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(summary = "코스 제목 수정")
    @PatchMapping("/{courseId}")
    public ApiResponse<Void> changeCourseTitle(
            @PathVariable Long courseId,
            @Valid @RequestBody CourseRequest.ChangeTitleDTO request
    ) {
        Long memberId = 1L;
        courseService.changeCourseTitle(memberId, courseId, request);
        return ApiResponse.OK;
    }

    @Operation(summary = "코스 키워드 검색")
    @GetMapping("/search")
    public ApiResponse<CourseResponse.CourseListResultDTO> searchCourses(
            @RequestParam(name = "keyword") String keyword,
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size
    ) {
        Long memberId = 1L;

        CourseResponse.CourseListResultDTO response = courseService.serchCourse(
                memberId,
                keyword,
                page,
                size
        );

        return ApiResponse.onSuccess(response);
    }
}