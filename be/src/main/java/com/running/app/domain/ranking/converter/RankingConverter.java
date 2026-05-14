package com.running.app.domain.ranking.converter;

import com.running.app.domain.ranking.dto.RankingResponse;
import com.running.app.domain.ranking.dto.RankingResponse.MyRank;
import com.running.app.domain.ranking.dto.RankingResponse.Ranking;
import com.running.app.domain.ranking.dto.RankingResponse.RecordRankingResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class RankingConverter {

    public static List<Ranking> toRanking(
            Map<Integer, String> nicknameMap,
            Map<Integer, Double> rankingTopTenMap) {

        List<RankingResponse.Ranking> rankingList = new ArrayList<>();

        // 순서가 보장된 LinkedHashMap 순회
        rankingTopTenMap.forEach((memberId, bestTime) -> {
            String nickname = nicknameMap.get(memberId);

            Ranking ranking = Ranking.builder()
                    .rank(rankingList.size() + 1)
                    .bestTime(bestTime)
                    .nickname(nickname)
                    .build();
            rankingList.add(ranking);
        });
        return rankingList;
    }

    public static RecordRankingResponse toRecordRankingResponse(
            List<Ranking> rankings,
            Integer rank,
            Double bestTime,
            String nickname,
            Integer totalCount
    ) {

        MyRank myRank = MyRank.builder()
                .rank(rank)
                .bestTime(bestTime)
                .nickname(nickname)
                .build();

        return RecordRankingResponse.builder()
                .totalCount(totalCount)
                .myRank(myRank)
                .rankings(rankings)
                .build();
    }

}
