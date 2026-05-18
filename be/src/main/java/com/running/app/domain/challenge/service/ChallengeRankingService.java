package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.dto.ChallengeResponse;

public interface ChallengeRankingService {

    // 챌린지 랭킹 화면에 필요한 모든 데이터를 조립하여 반환
    // 비로그인 시 loginId null → myRank, prevRank, myRunDistance, myRunStartedAt null 반환
    ChallengeResponse.ChallengeRankingResponse getChallengeRanking(
            String loginId, long challengeId);
}
