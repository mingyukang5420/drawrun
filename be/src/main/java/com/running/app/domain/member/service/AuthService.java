package com.running.app.domain.member.service;

import com.running.app.domain.member.converter.MemberConverter;
import com.running.app.domain.member.dto.MemberRequest.LoginRequest;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.dto.MemberResponse.LoginResponse;
import com.running.app.domain.member.dto.MemberResponse.ReissueResponse;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.global.Jwt.JwtUtil;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Slf4j
@RequiredArgsConstructor
@Service
public class AuthService {

    private static final String REFRESH_TOKEN_PREFIX = "refresh:";

    private final MemberRepository memberRepository;
    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final RedisTemplate<String, String> redisTemplate;

    public CheckDuplicationResponse checkNickname(String nickname) {
        return MemberConverter.toCheckDuplicationResponse(
                memberRepository.existsByNickname(nickname));
    }

    public CheckDuplicationResponse checkLoginId(String loginId) {
        return MemberConverter.toCheckDuplicationResponse(
                memberRepository.existsByLoginId(loginId));
    }

    public CheckDuplicationResponse checkEmail(String email) {
        return MemberConverter.toCheckDuplicationResponse(
                memberRepository.existsByEmail(email));
    }

    public LoginResponse login(LoginRequest request) {

        // login / password 검증
        Authentication authenticate = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        request.getLoginId(),
                        request.getPassword()
                )
        );

        String loginId = authenticate.getName();

        // accessToken 및 refreshToken 생성
        String accessToken = jwtUtil.generateAccessToken(loginId);
        String refreshToken = jwtUtil.generateRefreshToken(loginId);

        redisTemplate.opsForValue().set(
                getRefreshTokenKey(loginId),
                refreshToken,
                Duration.ofMillis(jwtUtil.getRefreshTokenExpiration())
        );

        return MemberConverter.toLoginResponse(accessToken, refreshToken);
    }

    public ReissueResponse reissue(String refreshToken) {
        validateRefreshToken(refreshToken);

        String loginId = jwtUtil.getLoginId(refreshToken);
        String savedRefreshToken = redisTemplate.opsForValue().get(getRefreshTokenKey(loginId));

        if (savedRefreshToken == null || !savedRefreshToken.equals(refreshToken)) {
            throw new GeneralException(ErrorStatus.INVALID_REFRESH_TOKEN);
        }

        String newAccessToken = jwtUtil.generateAccessToken(loginId);
        return MemberConverter.toReissueResponse(newAccessToken);
    }

    public void logout(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            return;
        }

        if (!jwtUtil.validateToken(refreshToken)) {
            return;
        }

        if (!"refresh".equals(jwtUtil.getTokenType(refreshToken))) {
            return;
        }

        String loginId = jwtUtil.getLoginId(refreshToken);
        redisTemplate.delete(getRefreshTokenKey(loginId));
    }

    private void validateRefreshToken(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new GeneralException(ErrorStatus.INVALID_REFRESH_TOKEN);
        }

        if (!jwtUtil.validateToken(refreshToken)) {
            throw new GeneralException(ErrorStatus.INVALID_REFRESH_TOKEN);
        }

        if (!"refresh".equals(jwtUtil.getTokenType(refreshToken))) {
            throw new GeneralException(ErrorStatus.INVALID_REFRESH_TOKEN);
        }
    }

    private String getRefreshTokenKey(String loginId) {
        return REFRESH_TOKEN_PREFIX + loginId;
    }
}
