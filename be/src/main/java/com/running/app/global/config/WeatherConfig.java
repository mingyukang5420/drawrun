package com.running.app.global.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class WeatherConfig {

    // application.yml에서 기상청 API base URL 주입
    @Value("${weather.api.base-url}")
    private String baseUrl;

    // RestClient Bean 등록
    // WeatherApiClient에서 이걸 주입받아서 기상청 API 호출
    @Bean
    public RestClient weatherRestClient() {
        return RestClient.builder()
                .baseUrl(baseUrl)
                .build();
    }
}
