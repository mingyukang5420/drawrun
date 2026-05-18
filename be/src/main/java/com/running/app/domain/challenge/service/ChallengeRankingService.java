package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.dto.ChallengeResponse;

public interface ChallengeRankingService {

    // 챌린지 랭킹 화면에 필요한 모든 데이터를 조립하여 반환
    // 챌린지 미참가 시 myRunDistance, myRunStartedAt null 반환
    ChallengeResponse.ChallengeRankingResponse getChallengeRanking(
            String loginId, long challengeId);

    // 챌린지 목록 조회 시 내 순위 단독 조회용
    ChallengeResponse.RankEntryDTO getMyChallengeRanking(String loginId, long challengeId);
}
