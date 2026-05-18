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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class TestService {

    private final ChallengeRepository challengeRepository;
    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final ChallengeOutlineExtractService challengeOutlineExtractService;
    private final SimilarityService similarityService;

    @Transactional
    public void testPipeline() {

        String object = challengeImageGenerateService.callTextModel();
        ChallengeImageGenerateService.ImageModelResult imageResult =
                challengeImageGenerateService.callImageModel(object);

        Challenge build = Challenge.builder()
                .title(object)
                .endedAt(LocalDateTime.now().plusDays(14))
                .startedAt(LocalDateTime.now())
                .polygonPoints(challengeOutlineExtractService.extract(imageResult.b64Json()))
                .polygonImageUrl(imageResult.storedPath())
                .difficulty(ChallengeDifficulty.EASY)
                .build();

        challengeRepository.save(build);

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
