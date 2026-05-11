package com.running.app.domain.weather.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

public abstract class WeatherResponse {

    @Getter
    @Builder
    @AllArgsConstructor
    public static class Result {

        // 시/도 이름 (예: "서울시")
        private String sido;

        // 구 이름 (예: "송파구")
        private String gu;

        // 하늘상태 텍스트 (예: "맑음", "구름많음", "흐림")
        private String weather;

        // 강수형태 텍스트 (예: "없음", "비", "눈", "소나기")
        private String precipitation;

        // 기온 (예: 23)
        private Integer temperature;

        // 날씨 맞춤 메시지 (예: "오늘은 뛰기 정말 좋은 날이에요!")
        private String message;
    }
}