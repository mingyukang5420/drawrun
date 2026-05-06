package com.running.app.domain.course.service;

import com.running.app.domain.course.converter.CourseConverter;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.entity.CourseDistrict;
import com.running.app.domain.course.repository.CourseDistrictRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.entity.Track;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.MultiLineString;
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
            Double minDistance,
            Double maxDistance,
            List<String> regions,
            Boolean isCompleted,
            String sort
    ) {
        CourseDifficulty courseDifficulty = CourseDifficulty.from(difficulty);
        Pageable pageable = PageRequest.of(
                page,
                size,
                getSort(sort)
        );

        Slice<Course> courseSlice = getCourseSlice(
                memberId,
                courseDifficulty,
                minDistance,
                maxDistance,
                regions,
                isCompleted,
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
            Long memberId,
            CourseDifficulty difficulty,
            Double minDistance,
            Double maxDistance,
            List<String> regions,
            Boolean isCompleted,
            Pageable pageable
    ) {
        if (regions == null || regions.isEmpty()) {
            return courseRepository.findCourseSlice(
                    memberId,
                    difficulty,
                    minDistance,
                    maxDistance,
                    isCompleted,
                    pageable
            );
        }

        return courseRepository.findCourseSliceByRegions(
                memberId,
                difficulty,
                minDistance,
                maxDistance,
                regions,
                isCompleted,
                pageable
        );
    }

    private Sort getSort(String sort) {
        if (sort == null || sort.isBlank() || sort.equalsIgnoreCase("latest")) {
            return Sort.by(Sort.Direction.DESC, "registeredAt");
        }

        if (sort.equalsIgnoreCase("completionScore")) {
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

    // 에디터 저장 — Track 은 이미 저장된 상태로 들어옴.
    @Transactional
    public Course createFromEditor(Long memberId, Track track, String title) {
        CourseDifficulty difficulty = determineDifficulty(track.getDistance());

        Course course = CourseConverter.toCourseFromEditor(memberId, track, title, difficulty);
        Course saved = courseRepository.save(course);

        mapCourseDistricts(saved.getId(), track.getGeom());

        return saved;
    }

    // 거리 기반 난이도 자동 산정. 추후 elevation_gain 등 다중 입력으로 고도화 예정.
    private CourseDifficulty determineDifficulty(double distanceKm) {
        if (distanceKm < 3.0) {
            return CourseDifficulty.BEGINNER;
        }
        if (distanceKm < 5.0) {
            return CourseDifficulty.EASY;
        }
        if (distanceKm < 10.0) {
            return CourseDifficulty.NORMAL;
        }
        return CourseDifficulty.HARD;
    }

    // TODO: District 의 boundary 컬럼 매핑이 추가되면 좌표 BBox 와 ST_Intersects 로 course_district 채움
    private void mapCourseDistricts(Long courseId, MultiLineString geom) {
    }

    @Transactional
    //코스 점수 계산해서 업데이트

    public void updateCompletionScore(Long courseId) {

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));

        Integer totalRunCount = runningRecordRepository.countByCourseId(courseId);
        Integer completedCount = runningRecordRepository.countByCourseIdAndIsCompletedTrue(
                courseId);

        Integer completionScore = calculateCompletionScore(
                completedCount,
                totalRunCount,
                course.getDifficulty()
        );

        course.changeCompletionScore(completionScore);
    }

    // 코스 점수 계산 로직
    private Integer calculateCompletionScore(Integer completedCount, Integer totalRunCount,
            CourseDifficulty difficulty) {
        //기본값 0
        if (totalRunCount == null || totalRunCount == 0) {
            return 0;
        }

        int safeCompletedCount = completedCount == null ? 0 : completedCount;
        double weight = difficulty.getWeight();

        double numerator = safeCompletedCount * weight;
        double denominator = totalRunCount + (safeCompletedCount * weight - safeCompletedCount);

        if (denominator == 0.0) {
            return 0;
        }

        int score = (int) Math.round((numerator / denominator) * 100);

        // 오차를 막기 위해 한번 더 0~100 으로 제한
        return Math.max(0, Math.min(100, score));
    }

    public CourseResponse.CourseDetailDTO getCourse(
            Long memberId,
            Long courseId
    ) {
        Course course = courseRepository.findByIdWithTrack(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        List<String> regions = getRegions(courseId);

        Boolean isCompleted = runningRecordRepository
                .existsByMemberIdAndCourseIdAndIsCompletedTrue(
                        memberId,
                        courseId
                );

        return CourseConverter.toDetailDTO(
                course,
                regions,
                isCompleted
        );
    }

    private List<String> getRegions(Long courseId) {

        return courseDistrictRepository.findAllByCourse_Id(courseId)
                .stream()
                .map(courseDistrict -> courseDistrict.getDistrict().getGu())
                .toList();
    }
}