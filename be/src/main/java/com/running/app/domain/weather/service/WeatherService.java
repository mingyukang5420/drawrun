package com.running.app.domain.weather.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.district.entity.District;
import com.running.app.domain.district.repository.DistrictRepository;
import com.running.app.domain.weather.dto.WeatherCacheDto;
import com.running.app.domain.weather.dto.WeatherResponse;
import com.running.app.domain.weather.type.PrecipitationType;
import com.running.app.domain.weather.type.SkyCondition;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class WeatherService {

    private final DistrictRepository districtRepository;
    private final RedisTemplate<String, Object> redisObjectTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public WeatherResponse.Result getWeather(Double lat, Double lng) {

        // 1. 위경도 → WKT 포맷으로 변환
        // WKT = Well-Known Text, 공간 데이터 표현 방식
        // 경도(lng) 먼저, 위도(lat) 나중 (PostGIS 표준)
        String wkt = String.format("POINT(%f %f)", lng, lat);

        // 2. 해당 좌표가 포함된 구 찾기
        List<District> districts = districtRepository.findDistrictsByGeomIntersects(wkt);

        if (districts.isEmpty()) {
            throw new GeneralException(ErrorStatus.DISTRICT_NOT_FOUND);
        }

        // 첫 번째 결과 사용
        District district = districts.getFirst();
        String gu = district.getGu();

        // 3. Redis에서 "weather:송파구" 키로 조회
        // Redis 역직렬화 시 LinkedHashMap으로 반환될 수 있어 직접 캐스팅 대신 ObjectMapper.convertValue() 사용
        String redisKey = "weather:" + gu;
        Object rawData = redisObjectTemplate.opsForValue().get(redisKey);
        WeatherCacheDto cached = objectMapper.convertValue(rawData, WeatherCacheDto.class);

        if (cached == null) {
            throw new GeneralException(ErrorStatus.WEATHER_DATA_UNAVAILABLE, gu);
        }

        // 4. 숫자 코드 → 텍스트 변환
        // Redis 에서 값을 꺼낼때 2차 null 방어
        if (cached.getSkyCondition() == null || cached.getPrecipitationType() == null
                || cached.getTemperature() == null) {
            throw new GeneralException(ErrorStatus.WEATHER_DATA_UNAVAILABLE, gu);
        }

        SkyCondition sky = SkyCondition.fromCode(cached.getSkyCondition());
        PrecipitationType pty = PrecipitationType.fromCode(cached.getPrecipitationType());

        // 5. WeatherResponse.Result 만들어서 반환
        return WeatherResponse.Result.builder()
                .sido(district.getSido())
                .gu(gu)
                .weather(sky.getLabel())
                .precipitation(pty.getLabel())
                .temperature(cached.getTemperature())
                .message(sky.getMessage())
                .build();
    }
}