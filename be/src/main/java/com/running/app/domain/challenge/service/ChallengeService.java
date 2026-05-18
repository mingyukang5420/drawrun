package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.ChallengeResponse;
import com.running.app.domain.challenge.entity.Challenge;
import com.running.app.domain.challenge.repository.ChallengeRepository;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import com.running.app.domain.member.entity.Member;
import com.running.app.domain.member.repository.MemberRepository;
import com.running.app.domain.record.repository.RunningRecordRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
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
    public List<String> getChallengeAllTitle() {
        return challengeRepository.findAllTitles();
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

        return ChallengeConverter.toParticipatedChallengeGroupDTOList(
                runningRecordRepository.findParticipatedChallengesByMemberId(memberId)
        );
    }
}
