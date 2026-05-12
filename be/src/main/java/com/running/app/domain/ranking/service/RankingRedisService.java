package com.running.app.domain.ranking.service;

import com.running.app.domain.record.projection.RankingQueryResult;
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
}
