package com.running.app.domain.challenge.converter;

import com.running.app.domain.challenge.dto.ChallengeResponse;
import com.running.app.domain.challenge.dto.ChallengeResponse.ParticipatedChallengeGroupDTO;
import com.running.app.domain.challenge.dto.GmsImageDTO;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageRequest;
import com.running.app.domain.challenge.dto.GmsImageDTO.ImageRequestBody;
import com.running.app.domain.challenge.dto.GmsTextDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.projection.ChallengeParticipationQueryResult;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public abstract class ChallengeConverter {

    public static GmsTextRequest toGmsTextRequest(String model,
            GmsTextDTO.RequestMessage requestMessage, Double temperature) {

        return GmsTextRequest.builder()
                .model(model)
                .messages(List.of(requestMessage))
                .temperature(temperature)
                .build();
    }

    public static GmsTextDTO.RequestMessage toRequestMessage(String prompt) {
        return GmsTextDTO.RequestMessage.builder()
                .role("system")
                .content(prompt)
                .build();
    }

    public static GmsImageDTO.GmsImageRequest toGmsImageRequest(String prompt, String model,
            ChallengeDifficulty difficulty, String object) {

        return GmsImageDTO.GmsImageRequest.builder()
                .model(model)
                .prompt(prompt)
                .n(1)
                .size("1024x1024")
                .outputFormat("png")
                .difficulty(difficulty)
                .object(object)
                .build();

    }

    public static Challenge toChallenge(String title, String imagePath, String polygonPoints,
            ChallengeDifficulty difficulty, String uuid) {

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
                .groupUUID(uuid)
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
                .startedAt(challenge.getStartedAt())
                .endedAt(challenge.getEndedAt())
                .challengeWeek(formatChallengeWeek(challenge.getStartedAt()))
                .dDay(formatDDay(challenge.getEndedAt()))
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


    // easy, hard의 요청 body를 내부 DTO로 합침
    public static ImageRequestBody toImageRequestBody(GmsImageRequest easyRequest,
            GmsImageRequest hardRequest) {

        return ImageRequestBody.builder()
                .easyImageBody(easyRequest)
                .hardImageBody(hardRequest)
                .build();
    }

    public static ParticipatedChallengeGroupDTO toParticipatedChallengeGroupDTO(String title,
            Map<ChallengeDifficulty, Long> map) {

        return ParticipatedChallengeGroupDTO.builder()
                .title(title)
                .easyChallengeId(map.get(ChallengeDifficulty.EASY))
                .hardChallengeId(map.get(ChallengeDifficulty.HARD))
                .build();
    }

    // 같은 타이틀 끼리 묶어주는 converter
    // repository에서 가져온 row를 grouped DTO List로 변환
    public static List<ChallengeResponse.ParticipatedChallengeGroupDTO> toParticipatedChallengeGroupDTOList(
            List<ChallengeParticipationQueryResult> results
    ) {
        // 정렬해서 가져오기 때문에 순서를 유지하기 위해 LinkedHashMap 사용
        // 같은 title을 두번 마주치며 easy, hard를 순서대로 채워야 하기 때문에 그 중간 상태인 builder를 map에 value로 삽입
        Map<String, ChallengeResponse.ParticipatedChallengeGroupDTO.ParticipatedChallengeGroupDTOBuilder> groupedMap
                = new LinkedHashMap<>();

        // repository에서 가져온 row 순회 시작
        for (ChallengeParticipationQueryResult result : results) {
            String title = result.getTitle();

            //groupedMap에 현재 title이 있으면 기존 builder를 꺼내고,
            //없으면 새로운 builder를 만들어 map에 삽입
            ChallengeResponse.ParticipatedChallengeGroupDTO.ParticipatedChallengeGroupDTOBuilder builder
                    = groupedMap.computeIfAbsent(
                    title,
                    key -> ChallengeResponse.ParticipatedChallengeGroupDTO.builder()
                            .title(key)
            );

            // 난이도에 따라 challengeId 채움
            if (result.getDifficulty() == ChallengeDifficulty.EASY) {
                builder.easyChallengeId(result.getChallengeId());
                // uuid값을 통해 다른 난이도의 challenge를 가져옴

            } else if (result.getDifficulty() == ChallengeDifficulty.HARD) {
                builder.hardChallengeId(result.getChallengeId());
            }
        }
        // map의 value가 builder단계이기 때문에, builder를 완성하고 리스트로 변환해서 반환
        return groupedMap.values().stream()
                .map(ChallengeResponse.ParticipatedChallengeGroupDTO.ParticipatedChallengeGroupDTOBuilder::build)
                .toList();
    }

    private static String formatChallengeWeek(LocalDateTime startedAt) {
        int month = startedAt.getMonthValue();
        int weekOfMonth = ((startedAt.getDayOfMonth() - 1) / 7) + 1;
        return month + "월 " + weekOfMonth + "주차";
    }

    // 종료일이 오늘이면 `D-Day`
    // 종료일까지 3일 남았으면 `D-3`
    // 이미 끝났으면 `종료`
    private static String formatDDay(LocalDateTime endedAt) {
        long days = java.time.temporal.ChronoUnit.DAYS.between(
                java.time.LocalDate.now(),
                endedAt.toLocalDate()
        );

        if (days == 0) {
            return "D-Day";
        }

        if (days > 0) {
            return "D-" + days;
        }

        return "종료";
    }

}
