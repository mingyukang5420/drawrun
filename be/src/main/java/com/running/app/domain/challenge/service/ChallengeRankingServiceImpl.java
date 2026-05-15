package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.dto.ChallengeResponse;
import com.running.app.domain.challenge.dto.ChallengeResponse.RankEntryDTO;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.projection.MemberNicknameQueryResult;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.ranking.service.RankingRedisService;
import com.running.app.domain.record.projection.ChallengeRankingQueryResult;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.ZSetOperations.TypedTuple;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ChallengeRankingServiceImpl implements ChallengeRankingService {

    private final RankingRedisService rankingRedisService;
    private final MemberRepository memberRepository;
    private final RunningRecordRepository runningRecordRepository;
    private final ChallengeRepository challengeRepository;

    // 현재 로그인한 사용자의 챌린지 순위 조회
    // Redis에서 reverseRank로 내 인덱스 조회 후 +1 처리하여 실제 순위로 변환
    // 챌린지 참가하지 않은 사용자면 null 반환
    @Override
    public RankEntryDTO getMyChallengeRanking(String loginId, long challengeId) {

        challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        String key = "ranking:challenge:" + challengeId;

        // Redis에서 내 순위 인덱스 조회 (0부터 시작하므로 +1 처리)
        Long rawRank = rankingRedisService.getMyChallengeRank(member.getMemberId().longValue(),
                key);
        if (rawRank == null) {
            return null;
        }
        int myRank = rawRank.intValue() + 1;

        // 내 유사도 점수 조회
        Double myScore = rankingRedisService.getMyRecord(member.getMemberId(), key);

        return ChallengeResponse.RankEntryDTO.builder()
                .rank(myRank)
                .nickname(member.getNickname())
                .similarityScore(myScore != null ? BigDecimal.valueOf(myScore) : null)
                .build();
    }

    // 현재 로그인한 사용자 바로 앞 순위 조회
    // myRank가 6위 이하면 이미 top5에 포함되므로 null 반환
    // myRank가 7위 이상이면 myRank - 1 순위 사람 정보 반환
    @Override
    public RankEntryDTO getPrevRanking(String loginId, long challengeId) {

        challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        String key = "ranking:challenge:" + challengeId;

        Long rawRank = rankingRedisService.getMyChallengeRank(member.getMemberId().longValue(),
                key);
        if (rawRank == null) {
            return null;
        }

        int myRank = rawRank.intValue() + 1;

        // 6위 이하면 이미 top5에 포함되므로 prevRank 불필요
        if (myRank <= 6) {
            return null;
        }

        // 내 바로 앞 순위 = rawRank - 1 인덱스
        TypedTuple<String> prevTuple = rankingRedisService.getMemberAtRank(key, rawRank - 1);
        if (prevTuple == null) {
            return null;
        }

        Long prevMemberId = Long.parseLong(prevTuple.getValue());
        Member prevMember = memberRepository.findById(prevMemberId.intValue()).orElse(null);

        return RankEntryDTO.builder()
                .rank(myRank - 1)
                .nickname(prevMember != null ? prevMember.getNickname() : null)
                .similarityScore(prevTuple.getScore() != null ?
                        BigDecimal.valueOf(prevTuple.getScore()) : null)
                .build();
    }

    // 챌린지 상위 5명 랭킹 조회
    // Redis에 데이터 없으면 DB에서 lazy load 후 적재
    // memberId로 닉네임 조회 후 RankEntityDTO 리스트로 조립하려 반환
    @Override
    public List<RankEntryDTO> getChallengeRaking(long challengeId) {

        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        String key = "ranking:challenge:" + challengeId;

        // Redis에 데이터 없으면 DB에서 가져와서 적재
        if (!rankingRedisService.isHaveRank(key)) {
            log.info("챌린지 Redis 데이터 없음. DB에서 적재 시작");
            List<ChallengeRankingQueryResult> rankingResults =
                    runningRecordRepository.findRankingByChallengeId(challengeId);
            rankingRedisService.setChallengeRankingValue(rankingResults, challengeId,
                    challenge.getEndedAt());
        }

        // 상위 5명 조회 (memberId, similarityScore)
        Map<Long, Double> topFiveMap = rankingRedisService.getChallengeRankingTopFive(key);

        // memberId로 닉네임 조회
        List<MemberNicknameQueryResult> members = memberRepository.findAllByMemberIdIn(
                topFiveMap.keySet().stream().map(Long::intValue).collect(Collectors.toSet())
        );
        Map<Long, String> nicknameMap = new HashMap<>();
        for (MemberNicknameQueryResult member : members) {
            nicknameMap.put(member.getMemberId().longValue(), member.getNickname());
        }

        // 순서 보장된 Map 순회하며 DTO 조립 (rank는 순서대로 1,2,3,4,5)
        List<RankEntryDTO> rankings = new ArrayList<>();
        topFiveMap.forEach((memberId, score) -> {
            rankings.add(RankEntryDTO.builder()
                    .rank(rankings.size() + 1)
                    .nickname(nicknameMap.get(memberId))
                    .similarityScore(BigDecimal.valueOf(score))
                    .build());
        });

        return rankings;
    }


}
