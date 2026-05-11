package com.running.app.domain.bookmark.service;

import com.running.app.domain.bookmark.converter.CourseBookmarkConverter;
import com.running.app.domain.bookmark.entity.CourseBookmark;
import com.running.app.domain.bookmark.repository.CourseBookmarkRepository;
import com.running.app.domain.course.converter.CourseConverter;
import com.running.app.domain.course.dto.CourseResponse;
import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.entity.CourseDistrict;
import com.running.app.domain.course.repository.CourseDistrictRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CourseBookmarkService {

    private final MemberRepository memberRepository;
    private final CourseRepository courseRepository;
    private final CourseBookmarkRepository courseBookmarkRepository;
    private final CourseDistrictRepository courseDistrictRepository;
    private final RunningRecordRepository runningRecordRepository;


    //북마크 추가
    @Transactional
    public void addBookmark(String loginId, Long courseId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        Course course = courseRepository.findById(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        if (courseBookmarkRepository.existsByMemberIdAndCourse_Id(memberId, courseId)) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }

        CourseBookmark courseBookmark = CourseBookmarkConverter.toCourseBookmark(
                memberId,
                course
        );

        courseBookmarkRepository.save(courseBookmark);
    }
    
    // 북마크 삭제
    @Transactional
    public void removeBookmark(String loginId, Long courseId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();
        
        CourseBookmark courseBookmark = courseBookmarkRepository.findByMemberIdAndCourse_Id(memberId, courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));
        
        courseBookmarkRepository.delete(courseBookmark);
    }
    
    // 북마크 목록 조회
    public CourseResponse.CourseListResultDTO getMyBookmarkedCourses(
            String loginId,
            Integer page,
            Integer size
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        Pageable pageable = PageRequest.of(
                page,
                size,
                Sort.by(Sort.Direction.DESC, "createdAt")
        );

        Slice<CourseBookmark> bookmarkSlice = courseBookmarkRepository.findMyBookmarkSlice(
                memberId,
                pageable
        );

        List<Course> courses = bookmarkSlice.getContent().stream()
                .map(CourseBookmark::getCourse)
                .toList();

        Map<Long, List<String>> regionMap = getRegionMap(courses);
        Set<Long> completedCourseIds = getCompletedCourseIds(memberId, courses);

        List<CourseResponse.CourseListDTO> content = courses.stream()
                .map(course -> CourseConverter.toListDTO(
                        course,
                        regionMap.getOrDefault(course.getId(), List.of()),
                        completedCourseIds.contains(course.getId())
                ))
                .toList();

        return CourseConverter.toListResultDTO(bookmarkSlice, content);
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

}
