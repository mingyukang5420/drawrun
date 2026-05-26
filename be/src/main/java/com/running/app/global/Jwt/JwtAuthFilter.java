package com.running.app.global.Jwt;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
@RequiredArgsConstructor
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtUtil jwtUtil;

    private static final String ACCESS_TOKEN_BLACKLIST_PREFIX = "blacklist:access:";
    private final RedisTemplate<String, String> redisTemplate;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        // 1. Authorization 헤더에서 토큰 추출
        String token = request.getHeader("Authorization");

        // 2. "Bearer " 접두사 제거
        if (token != null && token.startsWith("Bearer ")) {
            token = token.substring(7);
        }

        // 2-2. 블랙리스트인지 체크
        if (token != null && isBlacklisted(token)) {
            filterChain.doFilter(request,response);
            return;
        }

        // 3. 토큰이 없으면 다음 필터로 넘김 (Security가 알아서 401 처리)
        if (token != null && jwtUtil.validateToken(token)) {

            // 4. 토큰 타입이 access인지 확인 (refresh 토큰으로 API 호출 방지)
            if ("access".equals(jwtUtil.getTokenType(token))) {

                // 5. 토큰에서 loginId 추출
                String loginId = jwtUtil.getLoginId(token);

                // 6. Authentication 객체 생성 (3개짜리 생성자 = 인증 완료 상태)
                UsernamePasswordAuthenticationToken authentication =
                        new UsernamePasswordAuthenticationToken(
                                loginId,    // principal
                                null,       // credentials (이미 검증했으니 null)
                                List.of()   // authorities
                        );

                // 7. SecurityContextHolder에 인증 정보 저장
                SecurityContextHolder.getContext().setAuthentication(authentication);
            }
        }

        // 8. 다음 필터로 넘김
        filterChain.doFilter(request, response);
    }

    // 블랙리스트 판별
    private boolean isBlacklisted(String token) {
        return Boolean.TRUE.equals(redisTemplate.hasKey(getAccessTokenBlacklistKey(token)));
    }

    private String getAccessTokenBlacklistKey(String token) {
        return ACCESS_TOKEN_BLACKLIST_PREFIX + token;
    }
}
