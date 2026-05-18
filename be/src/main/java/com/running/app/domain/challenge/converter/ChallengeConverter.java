package com.running.app.domain.challenge.converter;

import com.running.app.domain.challenge.dto.ChallengeResponse;
import com.running.app.domain.challenge.dto.GmsImageDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public abstract class ChallengeConverter {

    public static GmsTextRequest toGmsTextRequest(String model,
            GmsTextDTO.RequestMessage requestMessage) {

        return GmsTextRequest.builder()
                .model(model)
                .messages(List.of(requestMessage))
                .build();
    }

    public static GmsTextDTO.RequestMessage toRequestMessage(String prompt) {
        return GmsTextDTO.RequestMessage.builder()
                .role("system")
                .content(prompt)
                .build();
    }

    public static GmsImageDTO.GmsImageRequest toGmsImageRequest(String prompt, String model) {

        return GmsImageDTO.GmsImageRequest.builder()
                .model(model)
                .prompt(prompt)
                .n(1)
                .size("1024x1024")
                .outputFormat("png")
                .build();

    }

    public static Challenge toChallenge(String title, String imagePath, String polygonPoints,
            ChallengeDifficulty difficulty) {

        LocalDateTime now = LocalDateTime.now();

        // 시작일과 무관하게 다음주 월요일로 끝나는 날 지정
        LocalDateTime end = LocalDateTime.now()
                .with(TemporalAdjusters.next(DayOfWeek.MONDAY))
                .toLocalDate()
                .atStartOfDay();

        return Challenge.builder()
                .title(title)
                .polygonImageUrl(imagePath)
                .polygonPoints(polygonPoints)
                .startedAt(now)
                .endedAt(end)
                .difficulty(difficulty)
                .build();
    }

    public static ChallengeResponse.ChallengeDetailDTO toChallengeDetailDTO(
            Challenge challenge,
            List<ChallengeResponse.RankEntryDTO> rankings,
            ChallengeResponse.RankEntryDTO myRank,
            ChallengeResponse.RankEntryDTO prevRank,
            int totalCount) {

        return ChallengeResponse.ChallengeDetailDTO.builder()
                .challengeId(challenge.getId())
                .title(challenge.getTitle())
                .polygonImageUrl(challenge.getPolygonImageUrl())
                .startedAt(challenge.getStartedAt())
                .endedAt(challenge.getEndedAt())
                .totalCount(totalCount)
                .prevRank(prevRank)
                .myRank(myRank)
                .rankings(rankings)
                .build();
    }

    public static List<ChallengeResponse.RankEntryDTO> toRankEntryDTOList(
            Map<Long, Double> rankingMap,
            Map<Long, String> nicknameMap) {

        List<ChallengeResponse.RankEntryDTO> rankingList = new ArrayList<>();

        // 순서가 보장된 LinkedHashMap 순회
        rankingMap.forEach((memberId, score) -> {
            rankingList.add(ChallengeResponse.RankEntryDTO.builder()
                    .rank(rankingList.size() + 1)
                    .nickname(nicknameMap.get(memberId))
                    .similarityScore(score)
                    .build());
        });

        return rankingList;
    }

    public static ChallengeResponse.RankEntryDTO toRankEntryDTO(
            int rank,
            String nickname,
            Double score) {

        return ChallengeResponse.RankEntryDTO.builder()
                .rank(rank)
                .nickname(nickname)
                .similarityScore(score)
                .build();
    }

    public static ChallengeResponse.ChallengeSummaryDTO toChallengeSummaryDTO(
            Challenge challenge,
            Integer totalParticipantCount,
            ChallengeResponse.RankEntryDTO myRank
    ) {
        return ChallengeResponse.ChallengeSummaryDTO.builder()
                .challengeId(challenge.getId())
                .title(challenge.getTitle())
                .polygonImageUrl(challenge.getPolygonImageUrl())
                .totalParticipantCount(totalParticipantCount)
                .myBestSimilarityScore(
                        myRank != null ? myRank.getSimilarityScore() : null
                )
                .myBestRank(
                        myRank != null ? myRank.getRank() : null
                )
                .build();
    }

    public static ChallengeResponse.ChallengeListDTO toChallengeListDTO(
            ChallengeResponse.ChallengeSummaryDTO easy,
            ChallengeResponse.ChallengeSummaryDTO hard
    ) {
        return ChallengeResponse.ChallengeListDTO.builder()
                .easy(easy)
                .hard(hard)
                .build();
    }

}
