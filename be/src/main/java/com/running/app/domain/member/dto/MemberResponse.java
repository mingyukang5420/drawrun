package com.running.app.domain.member.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class MemberResponse {

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Schema(description = "중복 체크 응답")
    public static class CheckDuplicationResponse {

        @Schema(description = "중복 여부 (true: 중복, false: 사용 가능)", example = "false")
        private boolean isDuplicated;
    }

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Schema(description = "로그인 응답")
    public static class LoginResponse {

        @Schema(description = "로그인 응답 accessToken")
        private String accessToken;

        @JsonIgnore // refreshToken은 응답에서 구조적으로 제외함
        private String refreshToken;
    }

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class MyInfoResponse {

        private String nickname;
        private String email;
        private String birthDate;
        private String gender;
        private Integer totalMyCourse;
        private Integer totalMyRecord;
        private Integer totalMyBookmark;
    }

    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    @Schema(description = "accessToken 재발급 응답")
    public static class ReissueResponse {

        @Schema(description = "재발급된 accessToken")
        private String accessToken;
    }
}
