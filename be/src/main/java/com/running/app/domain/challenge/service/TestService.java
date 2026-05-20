package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
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
    private final RunningRecordRepository runningRecordRepository;
    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final ChallengeImageStorageService challengeImageStorageService;
    private final ChallengeOutlineExtractService challengeOutlineExtractService;
    private final SimilarityService similarityService;

    @Transactional
    public void backfillPolygonPoints(Long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
        String base64 = challengeImageStorageService.readAsBase64(challenge.getPolygonImageUrl());
        String polygonPoints = challengeOutlineExtractService.extract(base64);
        challenge.updatePolygonPoints(polygonPoints);
        challengeRepository.save(challenge);
        if (polygonPoints != null) {
            log.info("polygon_points 백필 완료. challengeId={}", challengeId);
        } else {
            log.warn("polygon_points 백필 실패(추출 결과 null). challengeId={}", challengeId);
        }
    }

    public Double testSimilarity(Long challengeId, List<TrackRequest.NodeDTO> nodes) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
        if (challenge.getPolygonPoints() == null) {
            throw new GeneralException(ErrorStatus.CHALLENGE_POLYGON_NOT_READY);
        }
        return similarityService.calculate(challenge.getPolygonPoints(), nodes);
    }

    @Transactional
    public Double backfillSimilarityScore(Long recordId) {
        RunningRecord record = runningRecordRepository.findById(recordId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        if (record.getChallengeId() == null) {
            throw new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND);
        }

        Challenge challenge = challengeRepository.findById(record.getChallengeId())
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        if (challenge.getPolygonPoints() == null) {
            throw new GeneralException(ErrorStatus.CHALLENGE_POLYGON_NOT_READY);
        }

        List<TrackRequest.NodeDTO> nodes = TrackConverter.toNodeDTOList(record.getTrack());
        Double score = similarityService.calculate(challenge.getPolygonPoints(), nodes);
        record.updateSimilarityScore(score);

        log.info("유사도 백필 완료. recordId={}, challengeId={}, score={}", recordId, record.getChallengeId(), score);
        return score;
    }
}
