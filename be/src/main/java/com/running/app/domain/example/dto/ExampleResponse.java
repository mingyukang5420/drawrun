package com.running.app.domain.example.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class ExampleResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "스웨거 테스트용 응답 DTO")
    public static class exampleResponseDTO {

        @Schema(example = "요청이 성공적으로 처리되었습니다.")
        private String message;

        @Schema(example = "테스트 데이터가 잘 전달되었습니다.")
        private String data;

        @Schema(description = "응답 시간")
        private LocalDateTime timestamp;
    }
}