package com.running.app.global.Jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.MalformedJwtException;
import io.jsonwebtoken.UnsupportedJwtException;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.SignatureException;
import jakarta.annotation.PostConstruct;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class JwtUtil {

    @Value(value = "${jwt.secret}")
    private String secretKey;
    @Value(value = "${jwt.access-token-expiration}")
    private long accessTokenExpiration;
    @Value(value = "${jwt.refresh-token-expiration}")
    private long refreshTokenExpiration;

    private SecretKey key;

    @PostConstruct
    public void init() {
        this.key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secretKey));
    }

    // access 토큰 생성 메서드
    public String generateAccessToken(String loginId) {
        return Jwts.builder()
                .subject(loginId)
                .claim("type", "access")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + accessTokenExpiration))
                .signWith(key)
                .compact();
    }

    // refresh 토큰 생성 메서드
    public String generateRefreshToken(String loginId) {
        return Jwts.builder()
                .subject(loginId)
                .claim("type", "refresh")
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + refreshTokenExpiration))
                .signWith(key)
                .compact();
    }

    // 토큰을 꺼내서 서명, 유효기간 및 서명을 검사하고 유효하면 true 유효하지 않으면 false 반환
    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith(key)
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (ExpiredJwtException e) {
            // 토큰 만료
            return false;
        } catch (MalformedJwtException e) {
            // 토큰 형식 오류
            return false;
        } catch (SignatureException e) {
            // 서명 불일치 (위변조 가능성)
            return false;
        } catch (UnsupportedJwtException | IllegalArgumentException e) {
            // 지원하지 않는 토큰 또는 토큰이 null/빈값
            return false;
        }
    }

    // 토큰에서 parser를 통해 토큰 정보를 꺼내오는 헬퍼 메서드
    private Claims getClaims(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    // 토큰에서 loginId 추출
    public String getLoginId(String token) {
        return getClaims(token).getSubject();
    }

    // 토큰에서 타입 추출 (access / refresh)
    public String getTokenType(String token) {
        return getClaims(token).get("type", String.class);
    }
}
