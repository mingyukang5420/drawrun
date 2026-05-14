package com.running.app.domain.member.controller;

import com.running.app.domain.member.dto.MemberResponse;
import com.running.app.domain.member.service.MemberService;
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
@RequestMapping("/v1/member")
public class MemberController {

    private final MemberService memberService;

    @Operation(summary = "내 정보 조회")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "조회 성공"
            )
    })
    @GetMapping("/me")
    public ApiResponse<MemberResponse.MyInfoResponse> getMyInfo(
            @AuthenticationPrincipal String loginId
    ) {
        return ApiResponse.onSuccess(memberService.getMyInfo(loginId));
    }

}
