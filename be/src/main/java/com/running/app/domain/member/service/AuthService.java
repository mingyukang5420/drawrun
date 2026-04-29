package com.running.app.domain.member.service;

import com.running.app.domain.member.converter.MemberConverter;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@RequiredArgsConstructor
@Service
public class AuthService {

    private final MemberRepository memberRepository;

    // AuthService
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
}
