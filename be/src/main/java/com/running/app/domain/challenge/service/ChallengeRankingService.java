package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.dto.ChallengeResponse;
import java.util.List;

public interface ChallengeRankingService {

    // 현재 사용자의 챌린지 랭킹 정보를 가공하여 DTO로 반환하는 메서드
    ChallengeResponse.RankEntryDTO getMyChallengeRanking(String loginId, long challengeId);

    // 현재 사용자 바로 앞 순위 정보를 가공하여 DTO로 반환하는 메서드
    ChallengeResponse.RankEntryDTO getPrevRanking(String loginId, long challengeId);

    // 챌린지에 참여한 모든 사용자의 랭킹을 조회하여 DTO로 반환하는 메서드
    List<ChallengeResponse.RankEntryDTO> getChallengeRaking(long challengeId);
}
