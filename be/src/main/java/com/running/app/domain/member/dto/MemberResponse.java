package com.running.app.domain.member.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
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
}
