package com.running.app.domain.challenge.controller;

import com.running.app.domain.challenge.dto.GmsImageDTO.ImageRequestBody;
import com.running.app.domain.challenge.dto.TestDTO;
import com.running.app.domain.challenge.scheduler.ChallengeScheduler;
import com.running.app.domain.challenge.service.ChallengeImageGenerateService;
import com.running.app.domain.challenge.service.TestService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
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
    private final ChallengeScheduler challengeScheduler;

    @Operation(summary = "텍스트 생성 모델 호출", description = "body에 EASY / HARD 중 하나 입력")
    @PostMapping("/text")
    public ApiResponse<Void> textRequest() {
        challengeImageGenerateService.callTextModel();
        return ApiResponse.OK;
    }

    @Operation(summary = "이미지 생성 모델 호출")
    @PostMapping("/img")
    public ApiResponse<Void> imgRequest(
            @RequestBody String request
    ) {
        ImageRequestBody imageRequestBody = challengeImageGenerateService.ImageRequestBodyBuilder(
                request);

        challengeImageGenerateService.callImageModel(imageRequestBody.getEasyImageBody());
        challengeImageGenerateService.callImageModel(imageRequestBody.getHardImageBody());

        return ApiResponse.OK;
    }

    @Operation(summary = "전체 흐름 테스트")
    @PostMapping("/pipeline")
    public ApiResponse<Void> pipeline() {
        challengeScheduler.schedulerTester();
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

    @Operation(summary = "기록 유사도 백필", description = "recordId에 해당하는 기존 러닝 기록의 유사도 점수를 재계산해 DB에 저장하고 반환합니다.")
    @PostMapping("/backfill-similarity/{recordId}")
    public ApiResponse<Double> backfillSimilarity(
            @PathVariable Long recordId
    ) {
        return ApiResponse.onSuccess(testService.backfillSimilarityScore(recordId));
    }

    @Operation(summary = "유사도 계산 테스트", description = "challengeId에 해당하는 챌린지 폴리곤과 전달된 GPS 노드의 유사도 점수(0~100)를 반환합니다.")
    @PostMapping("/similarity")
    public ApiResponse<Double> similarityTest(
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(value = """
                                    {
                                      "challengeId": 1,
                                      "nodes": [
                                        { "lat": 37.5000965, "lng": 126.997583 },
                                        { "lat": 37.500426,  "lng": 126.998230 },
                                        { "lat": 37.500403,  "lng": 126.998440 },
                                        { "lat": 37.500513,  "lng": 126.999657 },
                                        { "lat": 37.500491,  "lng": 127.001482 },
                                        { "lat": 37.500667,  "lng": 127.001979 },
                                        { "lat": 37.500930,  "lng": 127.002201 },
                                        { "lat": 37.500754,  "lng": 127.002394 },
                                        { "lat": 37.500360,  "lng": 127.002256 },
                                        { "lat": 37.500140,  "lng": 127.002504 },
                                        { "lat": 37.500053,  "lng": 127.002036 },
                                        { "lat": 37.500031,  "lng": 127.001592 },
                                        { "lat": 37.499263,  "lng": 127.001040 },
                                        { "lat": 37.499855,  "lng": 127.000431 },
                                        { "lat": 37.499811,  "lng": 126.998883 },
                                        { "lat": 37.499855,  "lng": 126.998440 },
                                        { "lat": 37.499811,  "lng": 126.998230 }
                                      ]
                                    }
                                    """)
                    )
            )
            @RequestBody TestDTO.SimilarityRequestDTO request
    ) {
        return ApiResponse.onSuccess(
                testService.testSimilarity(request.getChallengeId(), request.getNodes()));
    }

}
