package com.running.app.domain.ranking.service;

import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.projection.MemberNicknameQueryResult;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.ranking.converter.RankingConverter;
import com.running.app.domain.ranking.dto.RankingResponse.Ranking;
import com.running.app.domain.ranking.dto.RankingResponse.RecordRankingResponse;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class RankingService {

    private final RankingRedisService rankingRedisService;
    private final MemberRepository memberRepository;
    private final RunningRecordRepository runningRecordRepository;

    // 가상 스레드 활성화 되어있음
    @Transactional(readOnly = true)
    public RecordRankingResponse getRecordRanking(String loginId, long courseId) {

        // redis key 조립
        String key = "course:ranking:" + courseId;

        // redis에 데이터가 있는지 확인
        if (!rankingRedisService.isHaveRank(key)) {
            // redis에 데이터 적재

            rankingRedisService.setRankingValue(
                    runningRecordRepository.findRankingByCourseId(courseId), courseId);
        }

        // redis에 데이터가 있는 경우
        Member member = null;
        Integer memberId = null;
        String nickname = null;

        if (loginId != null) {
            member = memberRepository.findByLoginId(loginId)
                    .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
            memberId = member.getMemberId();
            nickname = member.getNickname();
        }

        // 내 랭킹 조회
        Long rawRank = rankingRedisService.getMyRank(memberId, key);
        Integer myRank = (rawRank != null) ? rawRank.intValue() + 1 : null;

        // 내 기록 조회
        Double myRecord = rankingRedisService.getMyRecord(memberId, key);
        // 총 기록 수 조회
        Integer totalCount = rankingRedisService.getTotalCount(key).intValue();

        // 상위 10명 랭킹 가져오기
        // value = memberId
        // score = 기록
        Map<Integer, Double> rankingTopTenMap = rankingRedisService.getRankingTopTen(key);
        Set<Integer> rankMemberIdSet = rankingTopTenMap.keySet();

        // 가져온 10명의 id, nickname 값 매핑
        List<MemberNicknameQueryResult> allRankedMembers = memberRepository.findAllByMemberIdIn(
                rankMemberIdSet);
        Map<Integer, String> nicknameMap = new HashMap<>();
        for (MemberNicknameQueryResult allRankedMember : allRankedMembers) {
            nicknameMap.put(allRankedMember.getMemberId(), allRankedMember.getNickname());
        }

        // 응답 DTO로 변환
        List<Ranking> rankings = RankingConverter.toRanking(nicknameMap, rankingTopTenMap);

        return RankingConverter.toRecordRankingResponse(rankings, myRank, myRecord,
                nickname, totalCount);
    }

}
