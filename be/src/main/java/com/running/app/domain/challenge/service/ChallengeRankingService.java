package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.dto.ChallengeResponse;

public interface ChallengeRankingService {

    // 챌린지 랭킹 화면에 필요한 모든 데이터를 조립하여 반환
    // 챌린지 미참가 시 myRunDistance, myRunStartedAt null 반환
    ChallengeResponse.ChallengeRankingResponse getChallengeRanking(
            String loginId, long challengeId);

    // 챌린지 목록 조회 시 내 순위 단독 조회용
    ChallengeResponse.RankEntryDTO getMyChallengeRanking(String loginId, long challengeId);

    // 랭킹 페이지 본인 항목 클릭 시 노출되는 본인의 챌린지 상세 조회
    // loginId + challengeId 로 본인 best 기록만 반환, 타인 정보 조회 불가
    // 미참가 시 RECORD_NOT_FOUND 던짐
    ChallengeResponse.MyChallengeDetailDTO getMyChallengeDetail(String loginId, long challengeId);
}
