package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.ChallengeResponse;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.projection.ChallengeParticipationQueryResult;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.time.LocalDateTime;
import java.time.temporal.WeekFields;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChallengeService {

    private final ChallengeRepository challengeRepository;
    private final RunningRecordRepository runningRecordRepository;
    private final ChallengeRankingService challengeRankingService;
    private final MemberRepository memberRepository;

    @Transactional
    public Challenge create(Challenge challenge) {

        return challengeRepository.save(challenge);
    }

    @Transactional(readOnly = true)
    public List<String> getChallengeAllTitle(ChallengeDifficulty difficulty) {
        return challengeRepository.findAllTitleByDifficulty(difficulty);
    }

    @Transactional(readOnly = true)
    public ChallengeResponse.ChallengeListDTO getChallengeList(String loginId) {
        //EASY 중 가장 최신 챌린지 가져옴
        Challenge easyChallenge = challengeRepository
                .findTopByDifficultyOrderByIdDesc(ChallengeDifficulty.EASY)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        //HARD 중 가장 최신 챌린지 가져옴
        Challenge hardChallenge = challengeRepository
                .findTopByDifficultyOrderByIdDesc(ChallengeDifficulty.HARD)
                .orElseThrow(() -> new GeneralException(ErrorStatus.CHALLENGE_NOT_FOUND));

        Integer easyParticipantCount = runningRecordRepository.countParticipantsByChallengeId(
                easyChallenge.getId()
        );

        Integer hardParticipantCount = runningRecordRepository.countParticipantsByChallengeId(
                hardChallenge.getId()
        );

        ChallengeResponse.RankEntryDTO easyMyRank =
                challengeRankingService.getMyChallengeRanking(loginId, easyChallenge.getId());

        ChallengeResponse.RankEntryDTO hardMyRank =
                challengeRankingService.getMyChallengeRanking(loginId, hardChallenge.getId());

        ChallengeResponse.ChallengeSummaryDTO easy =
                ChallengeConverter.toChallengeSummaryDTO(
                        easyChallenge,
                        easyParticipantCount,
                        easyMyRank
                );

        ChallengeResponse.ChallengeSummaryDTO hard =
                ChallengeConverter.toChallengeSummaryDTO(
                        hardChallenge,
                        hardParticipantCount,
                        hardMyRank
                );

        return ChallengeConverter.toChallengeListDTO(easy, hard);
    }

    @Transactional(readOnly = true)
    public List<ChallengeResponse.ParticipatedChallengeGroupDTO> getParticipatedChallenges(
            String loginId
    ) {
        Member member = memberRepository.findByLoginId(loginId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.MEMBER_NOT_FOUND));
        Long memberId = member.getMemberId().longValue();

        // 사용자가 참여한 챌린지 목록 조회
        List<ChallengeParticipationQueryResult> participatedList = runningRecordRepository.findParticipatedChallengesByMemberIdV2(
                memberId);

        // 챌린지 목록의 uuid 한번에 추출(순서 보장을 위해 LinkedHashSet 사용)
        Set<String> groupUUIDs = participatedList.stream()
                .map(ChallengeParticipationQueryResult::getGroupUUID)
                .collect(Collectors.toCollection(LinkedHashSet::new));

        // 추출한 uuid 목록을 통해 Easy/Hard 챌린지 한번에 조회
        List<Challenge> challengeList = challengeRepository.findByGroupUUIDIn(groupUUIDs);

        // 메모리에서 groupUUID → {EASY: id, HARD: id} 로 매핑
        Map<String, Map<ChallengeDifficulty, Long>> challengeMap = challengeList.stream()
                .collect(Collectors.groupingBy(
                        Challenge::getGroupUUID,
                        Collectors.toMap(Challenge::getDifficulty, Challenge::getId)
                ));

        // groupUUID -> title 매핑
        Map<String, String> titleMap = new HashMap<>();
        for (ChallengeParticipationQueryResult participated : participatedList) {
            String title = titleBuilder(participated.getTitle(), participated.getStartedAt());
            titleMap.put(participated.getGroupUUID(), title);
        }

        List<ChallengeResponse.ParticipatedChallengeGroupDTO> result = new ArrayList<>();
        // uuid 리스트를 순회하며 응답 조립
        for (String groupUUID : groupUUIDs) {
            // 응답에 포함시킴
            result.add(ChallengeConverter.toParticipatedChallengeGroupDTO(titleMap.get(groupUUID),
                    challengeMap.get(groupUUID)));

        }
        return result;
    }

    // 제목 변환을 위한 헬퍼 메서드
    private String titleBuilder(String title, LocalDateTime startedAt) {

        int year = startedAt.getYear();
        int month = startedAt.getMonthValue();
        int weekOfMont = startedAt.get(WeekFields.ISO.weekOfMonth());

        return year + "년 " + month + "월 " + weekOfMont + "주차 " + title;
    }
}
