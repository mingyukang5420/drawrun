package com.running.app.domain.weather.controller;

import com.running.app.domain.weather.dto.WeatherResponse;
import com.running.app.domain.weather.service.WeatherService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import lombok.RequiredArgsConstructor;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Validated
@Tag(name = "날씨", description = "날씨 조회 API")
@RestController
@RequestMapping("/v1")
@RequiredArgsConstructor
public class WeatherController {

    private final WeatherService weatherService;

    @Operation(summary = "날씨 조회", description = "위경도를 입력받아 현재 날씨를 반환합니다.")
    @GetMapping("/weather")
    public ApiResponse<WeatherResponse.Result> getWeather(
            @RequestParam @DecimalMin("-90.0") @DecimalMax("90.0") Double lat,
            @RequestParam @DecimalMin("-180.0") @DecimalMax("180.0") Double lng
    ) {
        return ApiResponse.onSuccess(weatherService.getWeather(lat, lng));
    }
}