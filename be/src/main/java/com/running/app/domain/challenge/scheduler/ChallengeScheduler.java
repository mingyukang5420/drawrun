package com.running.app.domain.challenge.scheduler;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsImageDTO.ImageRequestBody;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.service.ChallengeImageGenerateService;
import com.running.app.domain.challenge.service.ChallengeImageGenerateService.ImageModelResult;
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

            // 난이도에 따른 텍스트 생성
            String easyObject = challengeImageGenerateService.callTextModel(
                    ChallengeDifficulty.EASY);
            String hardObject = challengeImageGenerateService.callTextModel(
                    ChallengeDifficulty.HARD);

            // 내부 DTO 조립
            ImageRequestBody imageRequestBody = challengeImageGenerateService.ImageRequestBodyBuilder(
                    easyObject, hardObject);

            // 난이도에 따른 이미지 생성 메서드 호출 및 디스크 저장
            ImageModelResult easyImageResult = challengeImageGenerateService.callImageModel(
                    imageRequestBody.getEasyImageBody());

            ImageModelResult hardImageResult = challengeImageGenerateService.callImageModel(
                    imageRequestBody.getHardImageBody());

            // 이미지에서 폴리곤 윤곽선 좌표 추출
            String easyPolygonPoints = challengeOutlineExtractService.extract(
                    easyImageResult.b64Json());
            String hardPolygonPoints = challengeOutlineExtractService.extract(
                    hardImageResult.b64Json());
            // 로그 헬퍼 메서드 호출
            extractLog(easyObject, easyPolygonPoints);

            // challenge 저장 헬퍼 메서드 호출
            Challenge easyChallenge = saveChallenge(easyObject, easyImageResult.storedPath(),
                    easyPolygonPoints,
                    ChallengeDifficulty.EASY);
            log.info("EASY 챌린지 스케쥴러 저장 완료 저장된 챌린지 이름");

            Challenge hardChallenge = saveChallenge(hardObject, hardImageResult.storedPath(),
                    hardPolygonPoints,
                    ChallengeDifficulty.HARD);
            log.info("HARD 챌린지 스케쥴러 저장 완료 저장된 챌린지 이름");
        }
    }

    private void extractLog(String object, String polygonPoints) {

        if (polygonPoints != null) {
            log.info("easy 윤곽선 추출 완료, 저장된 챌린지 이름: {}", object);
        } else {
            log.warn("윤곽선 추출 실패(null), polygon_points 없이 챌린지 저장. 이름: {}", object);
        }
    }

    private Challenge saveChallenge(String object, String imagePath, String polygonPoints,
            ChallengeDifficulty difficulty
    ) {

        Challenge challenge = ChallengeConverter.toChallenge(object, imagePath, polygonPoints,
                difficulty);
        // challenge 저장 로직 호출
        return challengeService.create(challenge);

    }

    // 서버 시작 시 스케쥴러 실행
    @Async
    @EventListener(ApplicationReadyEvent.class)
    public void onRunServer() {
        generateChallenge();
    }

    public void schedulerTester() {

        // 난이도에 따른 텍스트 생성
        String easyObject = challengeImageGenerateService.callTextModel(
                ChallengeDifficulty.EASY);
        String hardObject = challengeImageGenerateService.callTextModel(
                ChallengeDifficulty.HARD);

        // 내부 DTO 조립
        ImageRequestBody imageRequestBody = challengeImageGenerateService.ImageRequestBodyBuilder(
                easyObject, hardObject);

        // 난이도에 따른 이미지 생성 메서드 호출 및 디스크 저장
        ImageModelResult easyImageResult = challengeImageGenerateService.callImageModel(
                imageRequestBody.getEasyImageBody());

        ImageModelResult hardImageResult = challengeImageGenerateService.callImageModel(
                imageRequestBody.getHardImageBody());

        // 이미지에서 폴리곤 윤곽선 좌표 추출
        String easyPolygonPoints = challengeOutlineExtractService.extract(
                easyImageResult.b64Json());
        String hardPolygonPoints = challengeOutlineExtractService.extract(
                hardImageResult.b64Json());
        // 로그 헬퍼 메서드 호출
        extractLog(easyObject, easyPolygonPoints);

        // challenge 저장 헬퍼 메서드 호출
        Challenge easyChallenge = saveChallenge(easyObject, easyImageResult.storedPath(),
                easyPolygonPoints,
                ChallengeDifficulty.EASY);
        log.info("EASY 챌린지 스케쥴러 저장 완료 저장된 챌린지 이름");

        Challenge hardChallenge = saveChallenge(hardObject, hardImageResult.storedPath(),
                hardPolygonPoints,
                ChallengeDifficulty.HARD);
        log.info("HARD 챌린지 스케쥴러 저장 완료 저장된 챌린지 이름");
    }
}
