package com.running.app.domain.challenge.scheduler;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.service.ChallengeImageGenerateService;
import com.running.app.domain.challenge.service.ChallengeOutlineExtractService;
import com.running.app.domain.challenge.service.ChallengeService;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class ChallengeScheduler {

    private final ChallengeRepository challengeRepository;
    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final ChallengeOutlineExtractService challengeOutlineExtractService;
    private final ChallengeService challengeService;

    @Scheduled(cron = "0 0 0 * * 1") // 매주 월요일 실행
    public void generateChallenge() {

        LocalDateTime resentChallengeEndTime = challengeRepository.findResentChallenge();

        // 챌린지가 없거나 가장 최근에 만들어진 챌린지 기간이 끝났다면
        if (resentChallengeEndTime == null || resentChallengeEndTime.isBefore(
                LocalDateTime.now())) {

            log.info("챌린지 스케쥴러 가동");

            // 이미지 생성 (storedPath + 원본 base64 반환)
            String object = challengeImageGenerateService.callTextModel();
            ChallengeImageGenerateService.ImageModelResult imageResult =
                    challengeImageGenerateService.callImageModel(object);

            // 이미지에서 폴리곤 윤곽선 좌표 추출
            String polygonPoints = challengeOutlineExtractService.extract(imageResult.b64Json());
            if (polygonPoints != null) {
                log.info("윤곽선 추출 완료, 저장된 챌린지 이름: {}", object);
            } else {
                log.warn("윤곽선 추출 실패(null), polygon_points 없이 챌린지 저장. 이름: {}", object);
            }

            Challenge challenge = ChallengeConverter.toChallenge(object, imageResult.storedPath(),
                    polygonPoints, ChallengeDifficulty.EASY);

            // challenge 저장 로직 호출
            Challenge saveChallenge = challengeService.create(challenge);

            log.info("챌린지 스케쥴러 저장 완료 저장된 챌린지 이름: {}", saveChallenge.getTitle());
        }
    }

    // 서버 시작 시 스케쥴러 실행
    @Async
    @EventListener(ApplicationReadyEvent.class)
    public void onRunServer() {
        generateChallenge();
    }
}
