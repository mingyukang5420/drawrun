package com.running.app.domain.member.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import com.running.app.domain.member.entity.Member.Gender;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class MemberRequest {

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    @Schema(description = "회원가입 요청 파라미터")
    public static class SignupRequest {

        @Schema(description = "로그인 아이디 최대 20자", example = "rlawhdals")
        @NotBlank
        @Size(max = 20)
        private String loginId;

        @Schema(description = "이메일", example = "jongmin@example.com")
        @NotBlank
        @Email
        private String email;

        @Schema(description = "비밀번호 (8~20자)", example = "password123!")
        @NotBlank
        @Size(min = 8, max = 20)
        private String password;

        @Schema(description = "닉네임 (최대 20자)")
        @NotBlank
        @Size(max = 20)
        private String nickname;

        @Schema(description = "생년월일 (yyyy.MM.dd)", example = "2000.09.15")
        @NotNull
        @JsonFormat(pattern = "yyyy.MM.dd")
        private LocalDate birthDate;

        @Schema(description = "성별", example = "MALE", allowableValues = {"MALE", "FEMALE"})
        @NotNull
        private Gender gender;
    }
}
