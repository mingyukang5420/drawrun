package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.dto.TestDTO;
import com.running.app.domain.challenge.service.ChallengeImageGenerateService;
import com.running.app.domain.challenge.service.TestService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;


/**
 * 프롬프트 및 전체 흐름 테스트용으로 사용하는 컨트롤러입니다.
 */
@RestController
@RequestMapping("/v1/call/test")
@RequiredArgsConstructor
@Tag(name = "테스트", description = "테스트")
@SecurityRequirement(name = "X-Test-Key")
public class TestController {

    private final ChallengeImageGenerateService challengeImageGenerateService;
    private final TestService testService;

    @Operation(summary = "텍스트 생성 모델 호출")
    @PostMapping("/text")
    public ApiResponse<Void> textRequest() {
        challengeImageGenerateService.callTextModel();
        return ApiResponse.OK;
    }

    @Operation(summary = "이미지 생성 모델 호출")
    @PostMapping("/img")
    public ApiResponse<String> imgRequest(
            @RequestBody TestDTO request
    ) {
        ChallengeImageGenerateService.ImageModelResult result =
                challengeImageGenerateService.callImageModel(request.getImgString());
        return ApiResponse.onSuccess(result.storedPath());
    }

    @Operation(summary = "전체 흐름 테스트")
    @PostMapping("/pipeline")
    public ApiResponse<Void> pipeline() {
        testService.testPipeline();
        return ApiResponse.OK;
    }

    @Operation(summary = "polygon_points 백필", description = "기존 챌린지 이미지에서 윤곽선을 추출해 polygon_points를 DB에 저장합니다.")
    @PostMapping("/backfill-polygon/{challengeId}")
    public ApiResponse<Void> backfillPolygon(
            @PathVariable Long challengeId
    ) {
        testService.backfillPolygonPoints(challengeId);
        return ApiResponse.OK;
    }

    @Operation(summary = "유사도 계산 테스트", description = "challengeId에 해당하는 챌린지 폴리곤과 전달된 GPS 노드의 유사도 점수(0~100)를 반환합니다.")
    @PostMapping("/similarity")
    public ApiResponse<Double> similarityTest(
            @RequestBody TestDTO.SimilarityRequestDTO request
    ) {
        return ApiResponse.onSuccess(testService.testSimilarity(request.getChallengeId(), request.getNodes()));
    }

}
