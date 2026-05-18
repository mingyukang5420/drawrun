package com.running.app.domain.challenge.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class ChallengeResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChallengeDetailDTO {

        private Long challengeId;
        private String title;
        private String polygonImageUrl;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private int totalCount;
        private RankEntryDTO prevRank;
        private RankEntryDTO myRank;
        private List<RankEntryDTO> rankings;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RankEntryDTO {

        private int rank;
        private String nickname;
        private BigDecimal similarityScore;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChallengeListDTO {

        private ChallengeSummaryDTO easy;
        private ChallengeSummaryDTO hard;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChallengeSummaryDTO {

        private Long challengeId;
        private String title;
        private String polygonImageUrl;
        private Integer totalParticipantCount;
        private BigDecimal myBestSimilarityScore;
        private Integer myBestRank;

    }


}
