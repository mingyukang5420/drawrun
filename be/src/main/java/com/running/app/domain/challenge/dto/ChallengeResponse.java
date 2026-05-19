package com.running.app.domain.challenge.dto;

import com.running.app.domain.track.dto.TrackRequest;
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
        private Double similarityScore;
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
        private Double myBestSimilarityScore;
        private Integer myBestRank;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private String challengeWeek;
        private String dDay;

    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChallengeRankingResponse {

        private Integer totalCount;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private LocalDateTime myRunStartedAt;
        private Double myRunDistance;
        private RankEntryDTO myRank;
        private RankEntryDTO prevRank;
        private List<RankEntryDTO> rankings;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ParticipatedChallengeGroupDTO {

        private String title;
        private Long easyChallengeId;
        private Long hardChallengeId;
    }

    // 랭킹 페이지에서 본인 항목 클릭 시 노출되는 본인의 챌린지 상세 응답.
    // findTopByMemberIdAndChallengeIdOrderBySimilarityScoreDesc 로 가져온
    // 본인의 베스트 기록을 기준으로 모든 필드가 채워진다.
    // 타인 정보 조회 불가 — Service 에서 loginId 기준으로 본인 기록만 조회한다.
    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class MyChallengeDetailDTO {

        private Long recordId;
        private String title;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private Integer runningTime;
        private Double distance;
        private Double avgPace;
        private Integer calories;
        private Integer cadence;
        private Double similarityScore;
        private Integer rank;
        private String trackImageUrl;
        private List<TrackRequest.NodeDTO> nodes;
    }

}
