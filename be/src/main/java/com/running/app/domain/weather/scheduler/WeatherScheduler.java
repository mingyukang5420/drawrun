package com.running.app.domain.weather.scheduler;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.district.entity.District;
import com.running.app.domain.district.repository.DistrictRepository;
import com.running.app.domain.weather.dto.WeatherCacheDto;
import jakarta.annotation.PostConstruct;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.concurrent.TimeUnit;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Slf4j
@Component
@RequiredArgsConstructor
public class WeatherScheduler {

    private final DistrictRepository districtRepository;
    private final RedisTemplate<String, Object> redisObjectTemplate;
    private final RestClient weatherRestClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${weather.api.key}")
    private String apiKey;

    // 기상청 업데이트 고정 시각
    private static final int[] BASE_HOURS = {2, 5, 8, 11, 14, 17, 20, 23};

    // 기상청 업데이트 시각마다 자동 실행
    // cron = "0 0 2,5,8,11,14,17,20,23 * * *"
    // 초 분 시 일 월 요일
    // 매일 2,5,8,11,14,17,20,23시 정각에 실행
    @Scheduled(cron = "0 0 2,5,8,11,14,17,20,23 * * *")
    public void updateWeather() {
        log.info("날씨 스케줄러 시작: {}", LocalDateTime.now());

        // 1. 전체 구 목록 조회
        List<District> districts = districtRepository.findAll();

        LocalDateTime now = LocalDateTime.now();
        String baseDate = now.format(DateTimeFormatter.ofPattern("yyyyMMdd"));
        String baseTime = getBaseTime(now);
        long ttl = calculateTtl(now);

        // 2. 각 구마다 기상청 API 호출 후 Redis 저장
        for (District district : districts) {
            try {
                // center_point → nx, ny 변환
                Point point = district.getCenterPoint();
                int[] grid = convertToGrid(point.getY(), point.getX());

                // 기상청 API 호출
                String response = weatherRestClient.get()
                        .uri(uriBuilder -> uriBuilder
                                .queryParam("serviceKey", apiKey)
                                .queryParam("pageNo", 1)
                                .queryParam("numOfRows", 100)
                                .queryParam("dataType", "JSON")
                                .queryParam("base_date", baseDate)
                                .queryParam("base_time", baseTime)
                                .queryParam("nx", grid[0])
                                .queryParam("ny", grid[1])
                                .build())
                        .retrieve()
                        .body(String.class);

                // 응답 파싱 -> WeatherCacheDto 생성
                WeatherCacheDto weatherData = parseWeatherResponse(response, baseTime);

                // Redis 저장 "weather:송파구"
                String redisKey = "weather:" + district.getGu();
                redisObjectTemplate.opsForValue().set(redisKey, weatherData, ttl, TimeUnit.SECONDS);

                log.info("날씨 저장 완료: {}", district.getGu());

            } catch (Exception e) {
                // 한 구 실패해도 다른 구는 계속 진행
                log.error("날씨 업데이트 실패: {}", district.getGu(), e);
            }
        }

        log.info("날씨 스케줄러 완료: {}", LocalDateTime.now());
    }

    // 스프링 시작할 때 한번 실행
    @PostConstruct
    public void init() {
        updateWeather();
    }

    // 기상청 JSON 응답 파싱
    private WeatherCacheDto parseWeatherResponse(String response, String baseTime) {
        try {
            JsonNode items = objectMapper.readTree(response)
                    .path("response").path("body").path("items").path("item");

            Integer temperature = null;
            Integer skyCondition = null;
            Integer precipitationType = null;

            // baseTime 다음 시각 예보 데이터 찾기
            String targetTime = getNextFcstTime(baseTime);

            for (JsonNode item : items) {
                String category = item.path("category").asText();
                String fcstTime = item.path("fcstTime").asText();

                if (!fcstTime.equals(targetTime)) {
                    continue;
                }

                switch (category) {
                    case "TMP" -> temperature = item.path("fcstValue").asInt();
                    case "SKY" -> skyCondition = item.path("fcstValue").asInt();
                    case "PTY" -> precipitationType = item.path("fcstValue").asInt();
                }
            }

            if (temperature == null || skyCondition == null || precipitationType == null) {
                throw new RuntimeException("기상청 응답에서 필수 데이터 누락: TMP/SKY/PTY");
            }

            return WeatherCacheDto.builder()
                    .temperature(temperature)
                    .skyCondition(skyCondition)
                    .precipitationType(precipitationType)
                    .build();

        } catch (Exception e) {
            throw new RuntimeException("기상청 API 응답 파싱 실패", e);
        }
    }

    // 현재 시각 기준 가장 최근 base_time 반환
    // 예: 현재 9:30 → "0800"
    private String getBaseTime(LocalDateTime now) {
        int hour = now.getHour();
        if (hour < BASE_HOURS[0]) {
            return "2300"; // 전날 23시 기준
        }
        int lastBase = BASE_HOURS[0];
        for (int base : BASE_HOURS) {
            if (hour >= base) {
                lastBase = base;
            }
        }
        return String.format("%02d00", lastBase);
    }

    // 다음 예보 시각 반환
    // 예: baseTime = "0800" → "0900"
    private String getNextFcstTime(String baseTime) {
        int hour = Integer.parseInt(baseTime.substring(0, 2));
        return String.format("%02d00", (hour + 1) % 24);
    }

    // 다음 기상청 업데이트 시각까지 남은 초 계산 (동적 TTL)
    private long calculateTtl(LocalDateTime now) {
        int hour = now.getHour();
        for (int base : BASE_HOURS) {
            if (base > hour) {
                LocalDateTime next = now.withHour(base).withMinute(0).withSecond(0);
                return Duration.between(now, next).getSeconds();
            }
        }
        // 23시 이후면 다음날 02:00까지
        LocalDateTime next = now.plusDays(1).withHour(2).withMinute(0).withSecond(0);
        return Duration.between(now, next).getSeconds();
    }

    // 위경도 → 기상청 격자좌표(nx, ny) 변환 (Lambert Conformal Conic)
    private int[] convertToGrid(double lat, double lon) {
        final double RE = 6371.00877;
        final double GRID = 5.0;
        final double SLAT1 = 30.0;
        final double SLAT2 = 60.0;
        final double OLON = 126.0;
        final double OLAT = 38.0;
        final double XO = 43;
        final double YO = 136;

        final double DEGRAD = Math.PI / 180.0;
        double re = RE / GRID;
        double slat1 = SLAT1 * DEGRAD;
        double slat2 = SLAT2 * DEGRAD;
        double olon = OLON * DEGRAD;
        double olat = OLAT * DEGRAD;

        double sn = Math.tan(Math.PI * 0.25 + slat2 * 0.5) /
                Math.tan(Math.PI * 0.25 + slat1 * 0.5);
        sn = Math.log(Math.cos(slat1) / Math.cos(slat2)) / Math.log(sn);
        double sf = Math.tan(Math.PI * 0.25 + slat1 * 0.5);
        sf = Math.pow(sf, sn) * Math.cos(slat1) / sn;
        double ro = Math.tan(Math.PI * 0.25 + olat * 0.5);
        ro = re * sf / Math.pow(ro, sn);

        double ra = Math.tan(Math.PI * 0.25 + lat * DEGRAD * 0.5);
        ra = re * sf / Math.pow(ra, sn);
        double theta = lon * DEGRAD - olon;
        if (theta > Math.PI) {
            theta -= 2.0 * Math.PI;
        }
        if (theta < -Math.PI) {
            theta += 2.0 * Math.PI;
        }
        theta *= sn;

        int nx = (int) Math.floor(ra * Math.sin(theta) + XO + 0.5);
        int ny = (int) Math.floor(ro - ra * Math.cos(theta) + YO + 0.5);

        return new int[]{nx, ny};
    }
}
