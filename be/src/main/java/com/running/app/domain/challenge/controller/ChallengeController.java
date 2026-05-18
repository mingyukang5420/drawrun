package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.dto.ChallengeResponse.ChallengeListDTO;
import com.running.app.domain.challenge.service.ChallengeService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/challenge")
public class ChallengeController {

    private final ChallengeService challengeService;

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

}
