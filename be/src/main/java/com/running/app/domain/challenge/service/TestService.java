package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class TestService {

    private final ChallengeRepository challengeRepository;
    private final ChallengeImageGenerateService challengeImageGenerateService;

    @Transactional
    public void testPipeline() {

        String object = challengeImageGenerateService.callTextModel();
        String imagePath = challengeImageGenerateService.callImageModel(object);

        Challenge build = Challenge.builder()
                .title(object)
                .endedAt(LocalDateTime.now().plusDays(14))
                .startedAt(LocalDateTime.now())
                .polygonImageUrl(imagePath)
                .difficulty(ChallengeDifficulty.EASY)
                .build();

        challengeRepository.save(build);

    }
}
