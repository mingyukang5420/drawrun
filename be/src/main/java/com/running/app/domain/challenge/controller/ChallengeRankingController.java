package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.dto.ChallengeResponse.ChallengeRankingResponse;
import com.running.app.domain.challenge.service.ChallengeRankingService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "ChallengeRanking", description = "챌린지 랭킹 조회 API")
@RestController
@RequiredArgsConstructor
@Slf4j
@RequestMapping("/v1/challenge")
public class ChallengeRankingController {

    private final ChallengeRankingService challengeRankingService;

    @Operation(
            summary = "챌린지 랭킹 조회",
            description = """
                    챌린지 랭킹 조회.
                    
                    반환 정보:
                    - 챌린지 시작일/종료일
                    - 전체 참가자 수
                    - top5 랭킹 (순위, 닉네임, 유사도 점수)
                    - 내 순위 (로그인 시, 미참가 시 null)
                    - 내 바로 앞 순위 (내가 7위 이상일 때만 반환, 6위 이하면 null)
                    - 내가 뛴 거리 (km)
                    - 내 참여 시간
                    
                    유사도 점수는 소수점 2자리까지 반환.
                    비로그인 시 myRank, prevRank, myRunDistance, myRunStartedAt null 반환.
                    """
    )
    @GetMapping("/{challengeId}/ranking")
    public ApiResponse<ChallengeRankingResponse> getChallengeRanking(
            @AuthenticationPrincipal String loginId,
            @PathVariable long challengeId
    ) {
        ChallengeRankingResponse response =
                challengeRankingService.getChallengeRanking(loginId, challengeId);
        return ApiResponse.onSuccess(response);
    }
}

