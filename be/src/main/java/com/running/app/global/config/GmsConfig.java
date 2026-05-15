package com.running.app.global.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
public class GmsConfig {

    @Bean
    public RestClient gmsRestClient(@Value("${GMS_KEY}") String apiKey) {
        return RestClient.builder()
                .baseUrl("https://gms.ssafy.io/gmsapi/")
                .defaultHeader("Authorization", "Bearer " + apiKey)
                .defaultHeader("Content-Type", "application/json")
                .build();
    }
}
