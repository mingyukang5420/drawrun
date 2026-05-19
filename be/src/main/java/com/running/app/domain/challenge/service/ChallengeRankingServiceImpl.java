package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.ChallengeResponse.ChallengeRankingResponse;
import com.running.app.domain.challenge.dto.ChallengeResponse.MyChallengeDetailDTO;
import com.running.app.domain.challenge.dto.ChallengeResponse.RankEntryDTO;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.projection.MemberNicknameQueryResult;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.ranking.service.RankingRedisService;
import com.running.app.domain.record.entity.RunningRecord;
import com.running.app.domain.record.projection.ChallengeRankingQueryResult;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.time.LocalDateTime;
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

    // 챌린지 랭킹 화면에 필요한 모든 데이터를 조립하여 반환
    // 챌린지 미참가 시 myRunDistance, myRunStartedAt null 반환
    @Override
    public ChallengeRankingResponse getChallengeRanking(String loginId, long challengeId) {

        // Challenge 1번만 조회 → startedAt, endedAt, Redis TTL 계산에 재사용
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        String key = "ranking:challenge:" + challengeId;

        // Redis에 데이터 없으면 DB에서 lazy load 후 적재
        ensureRedisLoaded(key, challengeId, challenge);

        // top5 랭킹 조회
        List<RankEntryDTO> rankings = getTopFive(key);

        // 전체 참가자 수 (Redis ZCARD)
        Long countRaw = rankingRedisService.getChallengeRankingTotalCount(key);
        int totalCount = countRaw != null ? countRaw.intValue() : 0;

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        Long rawRank = rankingRedisService.getMyChallengeRank(
                member.getMemberId().longValue(), key);
        RankEntryDTO myRank = getMyRank(member, rawRank, key);
        RankEntryDTO prevRank = getPrevRank(member, rawRank, key);

        // 챌린지 미참가 시 null 가능
        Double myRunDistance = null;
        LocalDateTime myRunStartedAt = null;

        RunningRecord myRecord = runningRecordRepository
                .findTopByMemberIdAndChallengeIdOrderBySimilarityScoreDesc(
                        member.getMemberId().longValue(), challengeId)
                .orElse(null);

        if (myRecord != null) {
            myRunDistance = myRecord.getTrack().getDistance();
            myRunStartedAt = myRecord.getStartedAt();
        }

        return ChallengeRankingResponse.builder()
                .totalCount(totalCount)
                .startedAt(challenge.getStartedAt())
                .endedAt(challenge.getEndedAt())
                .myRunDistance(myRunDistance)
                .myRunStartedAt(myRunStartedAt)
                .myRank(myRank)
                .prevRank(prevRank)
                .rankings(rankings)
                .build();
    }

    // Redis에 데이터 없으면 DB에서 가져와서 적재
    private void ensureRedisLoaded(String key, long challengeId, Challenge challenge) {
        if (!rankingRedisService.isHaveRank(key)) {
            log.info("챌린지 Redis 데이터 없음. DB에서 적재 시작");
            List<ChallengeRankingQueryResult> rankingResults =
                    runningRecordRepository.findRankingByChallengeId(challengeId);
            rankingRedisService.setChallengeRankingValue(rankingResults, challengeId,
                    challenge.getEndedAt());
        }
    }

    // 상위 5명 조회 후 RankEntryDTO 리스트로 조립
    private List<RankEntryDTO> getTopFive(String key) {
        Map<Long, Double> topFiveMap = rankingRedisService.getChallengeRankingTopFive(key);
        List<MemberNicknameQueryResult> members = memberRepository.findAllByMemberIdIn(
                topFiveMap.keySet().stream().map(Long::intValue).collect(Collectors.toSet())
        );
        Map<Long, String> nicknameMap = new HashMap<>();
        for (MemberNicknameQueryResult m : members) {
            nicknameMap.put(m.getMemberId().longValue(), m.getNickname());
        }
        return ChallengeConverter.toRankEntryDTOList(topFiveMap, nicknameMap);
    }

    // 내 순위 조회 (Redis reverseRank → 0-index이므로 +1 처리)
    // 챌린지 미참가 시 null 반환
    private RankEntryDTO getMyRank(Member member, Long rawRank, String key) {
        if (rawRank == null) {
            return null;
        }
        int myRank = rawRank.intValue() + 1;
        Double myScore = rankingRedisService.getMyRecord(member.getMemberId(), key);
        return ChallengeConverter.toRankEntryDTO(myRank, member.getNickname(), myScore);
    }

    // 내 바로 앞 순위 조회
    // 6위 이하면 바로 앞 순위가 이미 top5에 포함되므로 null 반환
    // 7위 이상이면 rawRank - 1 인덱스 멤버 정보 반환
    private RankEntryDTO getPrevRank(Member member, Long rawRank, String key) {
        if (rawRank == null) {
            return null;
        }
        int myRank = rawRank.intValue() + 1;
        if (myRank <= 6) {
            return null;
        }
        TypedTuple<String> prevTuple = rankingRedisService.getMemberAtRank(key, rawRank - 1);
        if (prevTuple == null) {
            return null;
        }
        Long prevMemberId = Long.parseLong(prevTuple.getValue());
        Member prevMember = memberRepository.findById(prevMemberId.intValue()).orElse(null);
        return ChallengeConverter.toRankEntryDTO(
                myRank - 1,
                prevMember != null ? prevMember.getNickname() : null,
                prevTuple.getScore()
        );
    }

    // 챌린지 목록 조회 시 내 순위 단독 조회
    // ChallengeService에서 Easy/Hard 각각 호출
    @Override
    public RankEntryDTO getMyChallengeRanking(String loginId, long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        String key = "ranking:challenge:" + challengeId;
        ensureRedisLoaded(key, challengeId, challenge);
        Long rawRank = rankingRedisService.getMyChallengeRank(
                member.getMemberId().longValue(), key);
        return getMyRank(member, rawRank, key);
    }

    // 랭킹 페이지에서 본인 항목 클릭 시 노출되는 본인의 챌린지 상세 조회.
    // findTopByMemberIdAndChallengeIdOrderBySimilarityScoreDesc 는 본인 + 챌린지 조건이
    // 동시에 걸려 있어 타인 기록이 섞일 가능성이 없다 (본인 권한 검사 자체 내장).
    // 미참가 (record 없음) 시 RECORD_NOT_FOUND 를 던져 FE 가 빈 상태로 분기 가능.
    @Override
    public MyChallengeDetailDTO getMyChallengeDetail(String loginId, long challengeId) {
        Challenge challenge = challengeRepository.findById(challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));

        RunningRecord record = runningRecordRepository
                .findTopByMemberIdAndChallengeIdOrderBySimilarityScoreDesc(
                        member.getMemberId().longValue(), challengeId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.RECORD_NOT_FOUND));

        // 본인 순위는 랭킹 Redis 에서 조회 — 1-based 변환.
        // best 기록이 존재하면 Redis 에도 본인 score 가 있으므로 rawRank 도 항상 not-null.
        String key = "ranking:challenge:" + challengeId;
        ensureRedisLoaded(key, challengeId, challenge);
        Long rawRank = rankingRedisService.getMyChallengeRank(
                member.getMemberId().longValue(), key);
        Integer rank = (rawRank != null) ? rawRank.intValue() + 1 : null;

        return ChallengeConverter.toMyChallengeDetailDTO(record, rank);
    }
}