package com.running.app.domain.member.service;

import com.running.app.domain.bookmark.repository.CourseBookmarkRepository;
import com.running.app.domain.course.repository.CourseRepository;
import com.running.app.domain.member.converter.MemberConverter;
import com.running.app.domain.member.dto.MemberRequest.SignupRequest;
import com.running.app.domain.member.dto.MemberResponse;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    private final CourseRepository courseRepository;
    private final RunningRecordRepository runningRecordRepository;
    private final CourseBookmarkRepository courseBookmarkRepository;

    public void createMember(SignupRequest request) {

        // Member 객체 변환
        Member member = MemberConverter.signupRequestToMember(request,
                passwordEncoder.encode(request.getPassword()));

        memberRepository.save(member);
    }

    public MemberResponse.MyInfoResponse getMyInfo(String loginId) {

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        Long memberId = member.getMemberId().longValue();

        Integer totalMyCourse = courseRepository.countByMemberIdAndDeletedAtIsNull(memberId);
        Integer totalMyRecord = runningRecordRepository.countByMemberId(memberId);
        Integer totalMyBookmark = courseBookmarkRepository.countByMemberId(memberId);

        return MemberConverter.toMyInfoResponse(
                member,
                totalMyCourse,
                totalMyRecord,
                totalMyBookmark
        );
    }
}
