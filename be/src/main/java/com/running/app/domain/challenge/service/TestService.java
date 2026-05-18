package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class TestService {

    private final ChallengeRepository challengeRepository;
    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final ChallengeImageStorageService challengeImageStorageService;
    private final ChallengeOutlineExtractService challengeOutlineExtractService;
    private final SimilarityService similarityService;

    @Transactional
    public void testPipeline() {

        String object = challengeImageGenerateService.callTextModel();
        ChallengeImageGenerateService.ImageModelResult imageResult =
                challengeImageGenerateService.callImageModel(object);
        String polygonPoints = challengeOutlineExtractService.extract(imageResult.b64Json());

        Challenge build = Challenge.builder()
                .title(object)
                .endedAt(LocalDateTime.now().plusDays(14))
                .startedAt(LocalDateTime.now())
                .polygonPoints(polygonPoints)
                .polygonImageUrl(imageResult.storedPath())
                .polygonPoints(polygonPoints)
                .difficulty(ChallengeDifficulty.EASY)
                .build();

        challengeRepository.save(build);

    }

    @Transactional
    public void backfillPolygonPoints(Long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
        String base64 = challengeImageStorageService.readAsBase64(challenge.getPolygonImageUrl());
        String polygonPoints = challengeOutlineExtractService.extract(base64);
        challenge.updatePolygonPoints(polygonPoints);
        log.info("polygon_points 백필 완료. challengeId={}, points={}", challengeId, polygonPoints);
    }

    public Double testSimilarity(Long challengeId, List<TrackRequest.NodeDTO> nodes) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
        if (challenge.getPolygonPoints() == null) {
            throw new GeneralException(ErrorStatus.CHALLENGE_POLYGON_NOT_READY);
        }
        return similarityService.calculate(challenge.getPolygonPoints(), nodes);
    }
}
