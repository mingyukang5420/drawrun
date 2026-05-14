package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.service.ChallengeImageGenerateService;
import com.running.app.domain.challenge.service.TestService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


/**
 * 프롬프트 및 전체 흐름 테스트용으로 사용하는 컨트롤러입니다.
 */
@RestController
@RequestMapping("/v1/call/test")
@Slf4j
@RequiredArgsConstructor
@Tag(name = "테스트", description = "테스트")
public class Testcontroller {

    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final TestService testService;

    @Operation(summary = "텍스트 생성 모델 호출")
    @GetMapping("/text")
    public ApiResponse<Void> textRequest() {
        challengeImageGenerateService.callTextModel();
        return ApiResponse.OK;
    }

    @Operation(summary = "이미지 생성 모델 호출")
    @PostMapping("/img")
    public ApiResponse<String> imgRequest(
            @RequestBody String imgString
    ) {
        String s = challengeImageGenerateService.callImageModel(imgString);
        return ApiResponse.onSuccess(s);
    }

    @Operation(summary = "전체 흐름 테스트")
    @PostMapping("pipeline")
    public ApiResponse<Void> pipeline() {

        testService.testPipeline();

        return ApiResponse.OK;
    }
}
