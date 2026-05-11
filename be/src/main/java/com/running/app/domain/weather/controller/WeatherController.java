package com.running.app.domain.weather.controller;

import com.running.app.domain.weather.dto.WeatherResponse;
import com.running.app.domain.weather.service.WeatherService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "날씨", description = "날씨 조회 API")
@RestController
@RequestMapping("/v1")
@RequiredArgsConstructor
public class WeatherController {

    private final WeatherService weatherService;

    @Operation(summary = "날씨 조회", description = "시도와 구를 입력받아 현재 날씨를 반환합니다.")
    @GetMapping("/weather")
    public ApiResponse<WeatherResponse.Result> getWeather(
            @RequestParam String sido,
            @RequestParam String gu
    ) {
        return ApiResponse.onSuccess(weatherService.getWeather(sido, gu));
    }
}