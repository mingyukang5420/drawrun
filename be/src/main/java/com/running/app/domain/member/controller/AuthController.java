package com.running.app.domain.member.controller;

import com.running.app.domain.member.dto.MemberRequest.SignupRequest;
import com.running.app.domain.member.dto.MemberResponse.CheckDuplicationResponse;
import com.running.app.domain.member.service.AuthService;
import com.running.app.domain.member.service.MemberService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Auth", description = "인증 관련")
@RestController
@Slf4j
@RequiredArgsConstructor
@RequestMapping("/v1/auth")
public class AuthController {

    private final MemberService memberService;
    private final AuthService authService;

    @Operation(summary = "회원가입 API")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "회원가입 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "유효하지 않은 요청값",
                    content = @Content(schema = @Schema(implementation = ApiResponse.class))
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "409",
                    description = "이미 존재하는 데이터 (아이디/이메일/닉네임 중복)",
                    content = @Content(schema = @Schema(implementation = ApiResponse.class))
            )
    })
    @PostMapping("/signup")
    public ApiResponse<Void> signup(
            @RequestBody @Valid SignupRequest request
    ) {

        memberService.createMember(request);
        return ApiResponse.OK;
    }

    @Operation(summary = "닉네임 중복 체크")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "중복 체크 성공 (isDuplicated: true=중복, false=사용 가능)"
            )
    })
    @GetMapping("/check/nickname")
    public ApiResponse<CheckDuplicationResponse> checkNickname(
            @Parameter(description = "중복 확인할 닉네임", example = "러닝왕")
            @RequestParam String nickname) {
        return ApiResponse.onSuccess(authService.checkNickname(nickname));
    }

    @Operation(summary = "아이디 중복 체크")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "중복 체크 성공 (isDuplicated: true=중복, false=사용 가능)"
            )
    })
    @GetMapping("/check/loginId")
    public ApiResponse<CheckDuplicationResponse> checkLoginId(
            @Parameter(description = "중복 확인할 아이디", example = "jongmin123")
            @RequestParam String loginId) {
        return ApiResponse.onSuccess(authService.checkLoginId(loginId));
    }

    @Operation(summary = "이메일 중복 체크")
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "중복 체크 성공 (isDuplicated: true=중복, false=사용 가능)"
            )
    })
    @GetMapping("/check/email")
    public ApiResponse<CheckDuplicationResponse> checkEmail(
            @Parameter(description = "중복 확인할 이메일", example = "jongmin@example.com")
            @RequestParam String email) {
        return ApiResponse.onSuccess(authService.checkEmail(email));
    }
}
