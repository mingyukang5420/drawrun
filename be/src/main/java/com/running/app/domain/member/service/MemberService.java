package com.running.app.domain.member.service;

import com.running.app.domain.member.converter.MemberConverter;
import com.running.app.domain.member.dto.MemberRequest.SignupRequest;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class MemberService {

    private final MemberRepository memberRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    public void createMember(SignupRequest request) {

        // Member 객체 변환
        Member member = MemberConverter.signupRequestToMember(request,
                passwordEncoder.encode(request.getPassword()));

        memberRepository.save(member);
    }
}
