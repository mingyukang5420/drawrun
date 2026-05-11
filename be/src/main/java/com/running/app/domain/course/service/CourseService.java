package com.running.app.domain.course.service;

import com.running.app.domain.course.converter.CourseConverter;
import com.running.app.domain.course.dto.CourseRequest;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.entity.CourseDistrict;
import com.running.app.domain.course.repository.CourseDistrictRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.course.type.CourseDifficulty;
import com.running.app.domain.district.entity.District;
import com.running.app.domain.district.repository.DistrictRepository;
import com.running.app.domain.record.entity.RunningRecord;
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
    private final DifficultyService difficultyService;
    private final DistrictRepository districtRepository;

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
        Set<Long> completedCourseIds = getCompletedCourseIds(memberId, courses);

        List<CourseResponse.CourseListDTO> content = courses.stream()
                .map(course -> CourseConverter.toListDTO(
                        course,
                        regionMap.getOrDefault(course.getId(), List.of()),
                        completedCourseIds.contains(course.getId())
                ))
                .toList();

        return CourseConverter.toListResultDTO(courseSlice, content);
    }
    // 기록에서 코스 생성 메서드
    @Transactional
    public Long createCourseFromRecord(Long memberId, Long recordId) {
        RunningRecord sourceRecord = runningRecordRepository.findByIdAndMemberId(recordId, memberId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        //코스 등록 가능 여부 검증
        validateCourseCreation(sourceRecord);

        //원본 기록의 track으로 난이도 계산
        CourseDifficulty difficulty = difficultyService.calculate(sourceRecord.getTrack());
        //코스 생성
        Course course = CourseConverter.toCourseFromRecord(memberId, sourceRecord, difficulty);
        //저장 후 courseId 반환
        Course savedCourse = courseRepository.save(course);

        // 지역 역산: track.geom이 boundary와 교차하는 district 조회 후 course_district 저장
        String trackWkt = sourceRecord.getTrack().getGeom().toText();
        List<District> districts = districtRepository.findDistrictsByGeomIntersects(trackWkt);
        List<CourseDistrict> courseDistricts = districts.stream()
                .map(district -> CourseDistrict.builder()
                        .course(savedCourse)
                        .district(district)
                        .build())
                .toList();
        courseDistrictRepository.saveAll(courseDistricts);

        return savedCourse.getId();
    }

    @Transactional
    public void changeCourseTitle(
            Long memberId,
            Long courseId,
            CourseRequest.ChangeTitleDTO request
    ) {
        Course course = courseRepository.findByIdAndMemberIdAndDeletedAtIsNull(courseId, memberId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        course.changeTitle(request.getTitle());
    }

    @Transactional
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

    public CourseResponse.CourseDetailDTO getCourse(
            Long memberId,
            Long courseId
    ) {
        Course course = courseRepository.findByIdWithTrack(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        List<String> regions = getRegions(courseId);
        Boolean isCompleted = runningRecordRepository.existsByMemberIdAndCourseIdAndIsCompletedTrue(
                memberId,
                courseId
        );

        return CourseConverter.toDetailDTO(course, regions, isCompleted);
    }

    public CourseResponse.CourseListResultDTO searchCourse(
            Long memberId,
            String keyword,
            Integer page,
            Integer size
    ) {
        if (keyword == null || keyword.isBlank()) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }

        // 기본 최신순 정렬
        Pageable pageable = PageRequest.of(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "createdAt")
        );

        Slice<Course> courseSlice = courseRepository.searchCourseSlice(
                keyword.trim(),
                pageable
        );

        List<Course> courses = courseSlice.getContent();
        Map<Long, List<String>> regionMap = getRegionMap(courses);
        Set<Long> completedCourseIds = getCompletedCourseIds(memberId, courses);

        List<CourseResponse.CourseListDTO> content = courses.stream()
                .map(course -> CourseConverter.toListDTO(
                        course,
                        regionMap.getOrDefault(course.getId(), List.of()),
                        completedCourseIds.contains(course.getId())
                ))
                .toList();

        return CourseConverter.toListResultDTO(courseSlice, content);
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
            return Sort.by(Sort.Direction.DESC, "createdAt");
        }

        if (sort.equalsIgnoreCase("completionScore")) {
            return Sort.by(Sort.Direction.DESC, "completionScore");
        }

        return Sort.by(Sort.Direction.DESC, "createdAt");
    }

    private Map<Long, List<String>> getRegionMap(List<Course> courses) {
        List<Long> courseIds = courses.stream()
                .map(Course::getId)
                .toList();

        if (courseIds.isEmpty()) {
            return Map.of();
        }

        List<CourseDistrict> courseDistricts = courseDistrictRepository.findAllByCourse_IdIn(courseIds);
        Map<Long, List<String>> regionMap = new HashMap<>();

        for (CourseDistrict courseDistrict : courseDistricts) {
            Long courseId = courseDistrict.getCourse().getId();
            String region = courseDistrict.getDistrict().getGu();

            regionMap.computeIfAbsent(courseId, key -> new ArrayList<>()).add(region);
        }

        return regionMap;
    }

    private Set<Long> getCompletedCourseIds(Long memberId, List<Course> courses) {
        List<Long> courseIds = courses.stream()
                .map(Course::getId)
                .toList();

        if (courseIds.isEmpty()) {
            return Set.of();
        }

        return new HashSet<>(runningRecordRepository.findCompletedCourseIds(memberId, courseIds));
    }

    // 코스 등록 가능 여부 검증 로직
    private void validateCourseCreation(RunningRecord sourceRecord) {
        // 이미 다른 코스의 원본기록이면 생성 불가
        if (courseRepository.existsBySourceRecord_Id(sourceRecord.getId())) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }

        //is_safe 가 false이면 생성 불가
        if (!Boolean.TRUE.equals(sourceRecord.getIsSafe())) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }

        //에디터 코스일 경우, is_completed가 true여야 생성 가능
        if (sourceRecord.getCourseDraftId() != null
                && !Boolean.TRUE.equals(sourceRecord.getIsCompleted())) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }
    }

    private Integer calculateCompletionScore(
            Integer completedCount,
            Integer totalRunCount,
            CourseDifficulty difficulty
    ) {
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
        return Math.max(0, Math.min(100, score));
    }

    private List<String> getRegions(Long courseId) {
        return courseDistrictRepository.findAllByCourse_Id(courseId)
                .stream()
                .map(courseDistrict -> courseDistrict.getDistrict().getGu())
                .toList();
    }
}
