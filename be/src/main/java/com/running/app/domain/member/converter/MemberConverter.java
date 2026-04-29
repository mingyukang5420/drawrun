package com.running.app.domain.member.converter;

import com.running.app.domain.member.dto.MemberRequest.SignupRequest;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.entity.Member;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public abstract class MemberConverter {

    public static Member signupRequestToMember(SignupRequest request, String encodedPassword) {

        return Member.builder()
                .loginId(request.getLoginId())
                .gender(request.getGender())
                .nickname(request.getNickname())
                .email(request.getEmail())
                .password(encodedPassword)
                .birthDate(request.getBirthDate())
                .build();
    }

    public static CheckDuplicationResponse toCheckDuplicationResponse(boolean result) {

        return new CheckDuplicationResponse(result);
    }
}
