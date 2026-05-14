package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChallengeService {

    private final ChallengeRepository challengeRepository;

    @Transactional
    public Challenge create(Challenge challenge) {

        return challengeRepository.save(challenge);
    }
}
