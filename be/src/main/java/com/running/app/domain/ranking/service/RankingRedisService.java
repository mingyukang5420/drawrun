package com.running.app.domain.ranking.service;

import com.running.app.domain.record.projection.ChallengeRankingQueryResult;
import com.running.app.domain.record.projection.RankingQueryResult;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.data.redis.core.ZSetOperations.TypedTuple;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class RankingRedisService {

    private final RedisTemplate<String, String> redisTemplate;

    // 랭킹 데이터를 redis에 적재함(key, member, score)
    public void setRankingValue(List<RankingQueryResult> rankingResults, long courseId) {

        log.info("Redis 적재 요청");
        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        // redis key: course:ranking:{courseId}
        String key = "course:ranking:" + courseId;

        for (int i = 0; i < rankingResults.size(); i++) {
            RankingQueryResult rankingResult = rankingResults.get(i);
            zSetOps.add(key, rankingResult.getMemberId().toString(), rankingResult.getBestTime());
        }
        // TTL 설정
        redisTemplate.expire(key, 24, TimeUnit.HOURS);
    }

    // 적재된 랭킹 데이터에서 key를 받아 상위 10명을 조회
    public Map<Integer, Double> getRankingTopTen(String key) {

        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();

        // 상위 10명과 score(기록) 같이 가져옴
        Set<TypedTuple<String>> rank = zSetOps.rangeWithScores(key, 0, 9);

        // score 기준으로 정렬된 순서를 보장하기 위해 LinkedHashMap
        Map<Integer, Double> memberRankMap = new LinkedHashMap<>();

        if (rank == null) {
            return memberRankMap;
        }

        rank.forEach(tuple -> {
            // value = memberId
            // score = 기록
            Integer value = Integer.parseInt(tuple.getValue());
            Double score = tuple.getScore();

            memberRankMap.put(value, score);
        });

        return memberRankMap;
    }

    /**
     * 리턴값이 인덱스의 번호를 반환하므로 랭크 사용 시 +1 처리하여 사용 필요
     */
    public Long getMyRank(Integer memberId, String key) {

        // 로그인 되어있지 않은 사용자의 기록 조회 불가
        if (memberId == null) {
            return null;
        }

        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();

        return zSetOps.rank(key, memberId.toString());
    }

    public Double getMyRecord(Integer memberId, String key) {

        if (memberId == null) {
            return null;
        }

        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        return zSetOps.score(key, memberId.toString());
    }

    public Long getTotalCount(String key) {

        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        return zSetOps.size(key);
    }

    public boolean isHaveRank(String key) {
        return redisTemplate.hasKey(key);
    }

    public void deleteRankValue(String key) {
        redisTemplate.delete(key);
    }

    // 챌린지 랭킹 데이터를 (records 테이블) DB에서 가져와 Redis에 적재함
    // key: ranking:challenge:{challengeId}, TTL: ended_at + 7일
    public void setChallengeRankingValue(List<ChallengeRankingQueryResult> rankingResult,
            long challengeId, LocalDateTime endedAt) {
        log.info("챌린지 Redis 적재 요청");
        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        String key = "ranking:challenge:" + challengeId;

        for (ChallengeRankingQueryResult result : rankingResult) {
            if (result.getBestSimilarityScore() != null) {
                zSetOps.add(key, result.getMemberId().toString(), result.getBestSimilarityScore());
            }
        }

        long ttlSeconds = ChronoUnit.SECONDS.between(LocalDateTime.now(), endedAt.plusDays(7));
        if (ttlSeconds > 0) {
            redisTemplate.expire(key, ttlSeconds, TimeUnit.SECONDS);
        }
    }

    // 챌린지 랭킹 상위 5명 조회 (유사도 높은 순 = 내림차순)
    public Map<Long, Double> getChallengeRankingTopFive(String key) {
        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        Set<TypedTuple<String>> rank = zSetOps.reverseRangeWithScores(key, 0, 4);

        Map<Long, Double> memberRankMap = new LinkedHashMap<>();
        if (rank == null) {
            return memberRankMap;
        }

        rank.forEach(tuple -> {
            memberRankMap.put(Long.parseLong(tuple.getValue()), tuple.getScore());
        });
        return memberRankMap;
    }

    // 내 챌린지 순위 조회 (내림차순 기준 인덱스, 사용시 +1 처리 필요)
    public Long getMyChallengeRank(Long memberId, String key) {
        if (memberId == null) {
            return null;
        }
        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        return zSetOps.reverseRank(key, memberId.toString());
    }

    // prevRanking용 특정 순위의 memberId와 score 조회
    public TypedTuple<String> getMemberAtRank(String key, long rankIndex) {
        ZSetOperations<String, String> zSetOps = redisTemplate.opsForZSet();
        Set<TypedTuple<String>> result = zSetOps.reverseRangeWithScores(key, rankIndex, rankIndex);
        if (result == null || result.isEmpty()) {
            return null;
        }
        return result.iterator().next();
    }

    // ZCARD: Sorted Set의 전체 원소 개수 반환 (O(1))
    public Long getChallengeRankingTotalCount(String key) {
        return redisTemplate.opsForZSet().zCard(key);
    }

}
