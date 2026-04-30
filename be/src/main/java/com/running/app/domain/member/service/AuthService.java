package com.running.app.domain.member.service;

import com.running.app.domain.member.converter.MemberConverter;
import com.running.app.domain.member.dto.MemberRequest.LoginRequest;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.dto.MemberResponse.LoginResponse;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.global.Jwt.JwtUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Slf4j
@RequiredArgsConstructor
@Service
public class AuthService {

    private final MemberRepository memberRepository;
    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;

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

        // 여기서 refreshToken 저장 구현 예정
        return MemberConverter.toLoginResponse(accessToken, refreshToken);
    }
}
