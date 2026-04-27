package com.running.app.domain.example.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Getter;
import lombok.Setter;

public abstract class ExampleRequest {

    @Getter
    @Setter
    @Schema(description = "스웨거 테스트용 요청 DTO")
    public static class exampleRequestDTO {

        @Schema(example = "ssafy_park")
        private String userId;

        @Schema(example = "안녕하세요, 스웨거 테스트 중입니다.")
        private String message;

        @Schema(example = "100")
        private int testNumber;
    }
}