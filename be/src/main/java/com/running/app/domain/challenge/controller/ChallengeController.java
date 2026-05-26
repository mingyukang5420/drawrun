package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.dto.ChallengeResponse.ChallengeListDTO;
import com.running.app.domain.challenge.dto.ChallengeResponse.ChallengeRankingResponse;
import com.running.app.domain.challenge.dto.ChallengeResponse.MyChallengeDetailDTO;
import com.running.app.domain.challenge.dto.ChallengeResponse.ParticipatedChallengeGroupDTO;
import com.running.app.domain.challenge.service.ChallengeRankingService;
import com.running.app.domain.challenge.service.ChallengeService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/challenge")
public class ChallengeController {

    private final ChallengeService challengeService;
    private final ChallengeRankingService challengeRankingService;

    @Operation(summary = "챌린지 목록 조회")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "챌린지 목록 조회 성공"
            )
    })
    @GetMapping
    public ApiResponse<ChallengeListDTO> getChallengeList(
            @AuthenticationPrincipal String loginId
    ) {
        return ApiResponse.onSuccess(challengeService.getChallengeList(loginId));
    }

    @Operation(summary = "챌린지 랭킹 조회", description = "상위 5명 랭킹, 내 순위, 바로 앞 순위를 반환합니다.")
    @GetMapping("/{challengeId}/ranking")
    public ApiResponse<ChallengeRankingResponse> getChallengeRanking(
            @AuthenticationPrincipal String loginId,
            @PathVariable long challengeId
    ) {
        return ApiResponse.onSuccess(
                challengeRankingService.getChallengeRanking(loginId, challengeId));
    }

    @Operation(summary = "참여한 챌린지 목록 조회")
    @GetMapping("/participated")
    public ApiResponse<List<ParticipatedChallengeGroupDTO>> getParticipatedChallenges(
            @AuthenticationPrincipal String loginId
    ) {
        return ApiResponse.onSuccess(
                challengeService.getParticipatedChallenges(loginId)
        );
    }

    @Operation(
            summary = "챌린지 본인 상세 조회",
            description = """
                    랭킹 페이지에서 본인 항목을 클릭했을 때 노출되는 본인의 챌린지 상세 정보.
                    JWT 의 loginId 와 challengeId 로 본인의 베스트 기록(가장 높은 similarityScore)을 조회한다.
                    타인 정보는 조회 불가능 -- 본인 record 에 한정된 쿼리이므로 권한 검사가 자체 내장.

                    응답에는 record 의 트랙 좌표 시퀀스(nodes)도 포함되어 FE 가 지도에 그릴 수 있다.
                    """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "조회 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 -- 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = """
                            대상 없음. 사유 코드:
                            - CHALLENGE_NOT_FOUND : challengeId 에 해당하는 챌린지 없음
                            - MEMBER_NOT_FOUND    : loginId 에 해당하는 사용자 없음
                            - RECORD_NOT_FOUND    : 본인의 챌린지 참여 기록이 없음 (미참가)
                            """
            )
    })
    @GetMapping("/{challengeId}/me")
    public ApiResponse<MyChallengeDetailDTO> getMyChallengeDetail(
            @AuthenticationPrincipal String loginId,
            @PathVariable long challengeId
    ) {
        return ApiResponse.onSuccess(
                challengeRankingService.getMyChallengeDetail(loginId, challengeId));
    }
}
