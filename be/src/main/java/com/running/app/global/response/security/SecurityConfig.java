package com.running.app.global.response.security;

import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * api 테스트를 위한 임시 요청 모두 허용 -> 회원가입 및 로그인 구현 시 삭제 or 수정 하세요.
 */

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {

        http
                // csrf 비활성화
                .csrf(csrf -> csrf.disable())
                // formLogin 및 httpBasic 인증 비활성화
                .formLogin(form -> form.disable())
                .httpBasic(basic -> basic.disable())
                // 사용자 정보를 세션에 저장하는 기본 설정 비활성화
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                // 요청 권한 설정(열어 둘 api 엔드포인트 설정)
                .authorizeHttpRequests(auth ->
                        auth.requestMatchers(
                                        // 여기에서 인증 없이 요청을 허용 할 url 입력
                                        "/api/v1/auth/check/*",
                                        "/api/v1/auth/signup",
                                        "/api/v1/auth/login"
                                ).permitAll()
                                .anyRequest().authenticated()
                );
        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(
                "http://127.0.0.1:5500",
                "http://localhost:5500"
        ));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }


    // password 단방향 해시 인코더
    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
