package com.running.app.domain.run.service;

import com.running.app.domain.course.entity.Course;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.coursedraft.entity.CourseDraft;
import com.running.app.domain.coursedraft.repository.CourseDraftRepository;
import com.running.app.domain.run.converter.RunConverter;
import com.running.app.domain.run.dto.RunRequest;
import com.running.app.domain.run.dto.RunResponse;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RunService {

    private final CourseRepository courseRepository;
    private final CourseDraftRepository courseDraftRepository;

    public RunResponse.StartDTO startRun(RunRequest.StartDTO request) {
        // request 유효성 검증
        validateStartRequest(request);

        // request에 courseId가 있으면 공식 코스 러닝
        if (request.getCourseId() != null) {
            return startCourseRun(request.getCourseId());
        }

        // request에 courseDraftId가 있으면 에디터 코스 러닝
        if (request.getCourseDraftId() != null) {
            return startCourseDraftRun(request.getCourseDraftId());
        }

        // 둘 다 없으면 자유 러닝 -> nodes는 null 반환
        return RunConverter.toFreeRunStartResponse();
    }

    private RunResponse.StartDTO startCourseRun(Long courseId) {
        // request로 받은 courseId로 공식 코스 조회
        Course course = courseRepository.findByIdWithTrack(courseId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        return RunConverter.toStartResponse(course.getTrack());
    }

    private RunResponse.StartDTO startCourseDraftRun(Long courseDraftId) {
        // request로 받은 courseDraftId로 임시 코스 조회
        CourseDraft courseDraft = courseDraftRepository.findById(courseDraftId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.COURSE_NOT_FOUND));

        return RunConverter.toStartResponse(courseDraft.getTrack());
    }

    private void validateStartRequest(RunRequest.StartDTO request) {
        // courseId와 courseDraftId가 동시에 들어오면 잘못된 요청으로 처리
        if (request.getCourseId() != null && request.getCourseDraftId() != null) {
            throw new GeneralException(ErrorStatus.BAD_REQUEST);
        }
    }
}
