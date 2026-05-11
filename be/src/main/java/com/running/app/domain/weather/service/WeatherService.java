package com.running.app.domain.weather.service;

import com.running.app.domain.district.entity.District;
import com.running.app.domain.district.repository.DistrictRepository;
import com.running.app.domain.weather.dto.WeatherCacheDto;
import com.running.app.domain.weather.dto.WeatherResponse;
import com.running.app.domain.weather.type.PrecipitationType;
import com.running.app.domain.weather.type.SkyCondition;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class WeatherService {

    private final DistrictRepository districtRepository;
    private final RedisTemplate<String, Object> redisObjectTemplate;

    public WeatherResponse.Result getWeather(String sido, String gu) {

        // sido, gu로 구 존재 여부 확인
        districtRepository.findBySidoAndGu(sido, gu)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 구입니다: " + sido + " " + gu));

        // Redis에서 "weather:송파구" 키로 조회
        String redisKey = "weather:" + gu;
        WeatherCacheDto cached = (WeatherCacheDto) redisObjectTemplate
                .opsForValue()
                .get(redisKey);

        // Redis에 데이터 없으면 예외
        if (cached == null) {
            throw new IllegalArgumentException("날씨 데이터가 없습니다: " + gu);
        }

        // 숫자 코드 → 텍스트 변환
        SkyCondition sky = SkyCondition.fromCode(cached.getSkyCondition());
        PrecipitationType pty = PrecipitationType.fromCode(cached.getPrecipitationType());

        // WeatherResponse.Result 만들어서 반환
        return WeatherResponse.Result.builder()
                .gu(gu)
                .weather(sky.getLabel())
                .precipitation(pty.getLabel())
                .temperature(cached.getTemperature())
                .message(sky.getMessage())
                .build();
    }
}