package com.running.app.domain.course.service;

import com.running.app.domain.course.converter.CourseConverter;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.entity.CourseDistrict;
import com.running.app.domain.course.repository.CourseDistrictRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.record.repository.RunningRecordRepository;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CourseService {

    private final CourseRepository courseRepository;
    private final CourseDistrictRepository courseDistrictRepository;
    private final RunningRecordRepository runningRecordRepository;

    public CourseResponse.CourseListResultDTO getCourseList(
            Long memberId,
            Integer page,
            Integer size,
            String difficulty,
            String sort
    ) {
        CourseDifficulty courseDifficulty = CourseDifficulty.from(difficulty);
        Pageable pageable = PageRequest.of(
                page,
                size,
                getSort(sort)
        );

        Slice<Course> courseSlice = getCourseSlice(
                courseDifficulty,
                pageable
        );

        List<Course> courses = courseSlice.getContent();

        Map<Long, List<String>> regionMap = getRegionMap(courses);
        Set<Long> completedCourseIds = getCompletedCourseIds(
                memberId,
                courses
        );

        List<CourseResponse.CourseListDTO> content = courses.stream()
                .map(course -> CourseConverter.toListDTO(
                        course,
                        regionMap.getOrDefault(course.getId(), List.of()),
                        completedCourseIds.contains(course.getId())
                ))
                .toList();

        return CourseConverter.toListResultDTO(
                courseSlice,
                content
        );
    }

    private Slice<Course> getCourseSlice(
            CourseDifficulty difficulty,
            Pageable pageable
    ) {
        if (difficulty == null) {
            return courseRepository.findAllByDeletedAtIsNullAndRegisteredAtIsNotNull(
                    pageable
            );
        }

        return courseRepository.findAllByDeletedAtIsNullAndRegisteredAtIsNotNullAndDifficulty(
                difficulty,
                pageable
        );
    }

    private Sort getSort(String sort) {
        if (sort == null || sort.isBlank() || sort.equalsIgnoreCase("latest")) {
            return Sort.by(Sort.Direction.DESC, "registeredAt");
        }

        if (sort.equalsIgnoreCase("completionScore")
                || sort.equalsIgnoreCase("completionRate")) {
            // 현재 completionRate 요청은 completionScore 기준으로 정렬.
            // completionScore는 records 기반 완주 점수 계산 결과를 courses.completion_score에 저장한 값.
            return Sort.by(Sort.Direction.DESC, "completionScore");
        }

        return Sort.by(Sort.Direction.DESC, "registeredAt");
    }

    private Map<Long, List<String>> getRegionMap(
            List<Course> courses
    ) {
        List<Long> courseIds = courses.stream()
                .map(Course::getId)
                .toList();

        if (courseIds.isEmpty()) {
            return Map.of();
        }

        List<CourseDistrict> courseDistricts = courseDistrictRepository
                .findAllByCourse_IdIn(courseIds);

        Map<Long, List<String>> regionMap = new HashMap<>();

        for (CourseDistrict courseDistrict : courseDistricts) {
            Long courseId = courseDistrict.getCourse().getId();
            String region = courseDistrict.getDistrict().getGu();

            regionMap.computeIfAbsent(
                    courseId,
                    key -> new ArrayList<>()
            ).add(region);
        }

        return regionMap;
    }

    private Set<Long> getCompletedCourseIds(
            Long memberId,
            List<Course> courses
    ) {
        List<Long> courseIds = courses.stream()
                .map(Course::getId)
                .toList();

        if (courseIds.isEmpty()) {
            return Set.of();
        }

        return new HashSet<>(
                runningRecordRepository.findCompletedCourseIds(
                        memberId,
                        courseIds
                )
        );
    }

    //코스 점수 계산해서 업데이트
    @Transactional
    public void updateCompletionScore(Long courseId) {

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));

        Integer totalRunCount = runningRecordRepository.countByCourseId(courseId);
        Integer completedCount = runningRecordRepository.countByCourseIdAndIsCompletedTrue(courseId);

        Integer completionScore = calculateCompletionScore(
                completedCount,
                totalRunCount,
                course.getDifficulty()
        );

        course.changeCompletionScore(completionScore);
    }

    // 코스 점수 계산 로직
    private Integer calculateCompletionScore(Integer completedCount, Integer totalRunCount, CourseDifficulty difficulty) {
        //기본값 0
        if(totalRunCount == null || totalRunCount == 0) {
            return 0;
        }

        int safeCompletedCount = completedCount == null ? 0 : completedCount;
        double weight = difficulty.getWeight();

        double numerator = safeCompletedCount * weight;
        double denominator = totalRunCount + (safeCompletedCount * weight - safeCompletedCount);

        if(denominator == 0.0){
            return 0;
        }

        int score = (int) Math.round((numerator / denominator) * 100);

        // 오차를 막기 위해 한번 더 0~100 으로 제한
        return Math.max(0, Math.min(100, score));
    }
}