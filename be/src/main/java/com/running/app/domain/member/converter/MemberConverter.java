package com.running.app.domain.member.converter;

import com.running.app.domain.member.dto.MemberRequest.SignupRequest;
import com.running.app.domain.member.dto.MemberResponse;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.dto.MemberResponse.LoginResponse;
import com.running.app.domain.member.dto.MemberResponse.ReissueResponse;
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

    public static LoginResponse toLoginResponse(String accessToken, String refreshToken) {

        return new LoginResponse(accessToken, refreshToken);
    }

    public static MemberResponse.MyInfoResponse toMyInfoResponse(
            Member member,
            Integer totalMyCourse,
            Integer totalMyRecord,
            Integer totalMyBookmark
    ) {
        return MemberResponse.MyInfoResponse.builder()
                .nickname(member.getNickname())
                .email(member.getEmail())
                .birthDate(formatBirthDate(member.getBirthDate()))
                .gender(member.getGender().name())
                .totalMyCourse(totalMyCourse)
                .totalMyRecord(totalMyRecord)
                .totalMyBookmark(totalMyBookmark)
                .build();
    }

    private static String formatBirthDate(java.time.LocalDate birthDate) {
        return String.format(
                "%d.%02d.%02d",
                birthDate.getYear(),
                birthDate.getMonthValue(),
                birthDate.getDayOfMonth()
        );

    public static ReissueResponse toReissueResponse(String accessToken) {

        return new ReissueResponse(accessToken);
    }
}
