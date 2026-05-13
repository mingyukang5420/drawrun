package com.running.app.domain.weather.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

// Redis에 저장하는 내부용 DTO
// 기상청 API에서 받은 원본 숫자 코드 그대로 저장
@Getter
@Builder
@AllArgsConstructor
@NoArgsConstructor  // Redis 역직렬화할 때 기본 생성자 필요
public class WeatherCacheDto {

    // 기온 (예: 23)
    private Integer temperature;

    // 하늘상태 코드 (1: 맑음, 3: 구름많음, 4: 흐림)
    private Integer skyCondition;

    // 강수형태 코드 (0: 없음, 1: 비, 2: 비/눈, 3: 눈, 4: 소나기)
    private Integer precipitationType;
}