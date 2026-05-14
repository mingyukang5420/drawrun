package com.running.app.domain.ranking.dto;

import java.util.List;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class RankingResponse {

    @Builder
    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    public static class RecordRankingResponse {

        private Integer totalCount;
        private MyRank myRank;
        private List<Ranking> rankings;
    }

    @Builder
    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    public static class MyRank {

        private Integer rank;
        private String nickname;
        private Double bestTime;
    }

    @Builder
    @Getter
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor
    public static class Ranking {

        private Integer rank;
        private String nickname;
        private Double bestTime;
    }
}
