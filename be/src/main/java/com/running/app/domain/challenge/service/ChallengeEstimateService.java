package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsVisionRequest;
import com.running.app.domain.challenge.dto.GmsImageDTO.ImageUrl;
import com.running.app.domain.challenge.dto.GmsImageDTO.VisionContent;
import com.running.app.domain.challenge.dto.GmsImageDTO.VisionRequestMessage;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Base64;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.coobird.thumbnailator.Thumbnails;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChallengeEstimateService {

    private final RestClient gmsRestClient;

    private static final String TEXT_MODEL = "gpt-5.2";
    private static final String TEXT_URI = "/api.openai.com/v1/chat/completions";
    private static final String TEXT_ESTIMATE_PROMPT = """
            You are evaluating whether a given object is suitable for a GPS running art challenge.
            
            Context you must understand before evaluating:
            - The object will be drawn as a 2D polygon silhouette using ONLY straight line segments
            - The drawing consists of ONLY the outer boundary — no interior lines, no texture, no internal detail
            - The entire outline must be a single continuous closed loop (like tracing with one pen stroke)
            - Curves and circles must be replaced with angular polygons
            - Two difficulty versions exist: EASY (simplified) and HARD (more detailed)
            - Users physically run the route on Korean city streets where most turns are 90 degrees
            
            Evaluate the object against these three criteria. For each, output PASS or FAIL:
            
            [A. Single Loop Feasibility]
            FAIL if: the object has inherently circular/curved dominant parts (e.g., key ring)
            FAIL if: the object consists of multiple disconnected parts (e.g., glasses, bicycle)
            FAIL if: interior lines are essential to recognition (e.g., corn, strawberry)
            Otherwise: PASS
            
            [B. Silhouette Recognizability]
            FAIL if: recognition depends on texture or surface pattern rather than outer shape
            FAIL if: a simplified (EASY) version would be indistinguishable from a generic shape
            Otherwise: PASS
            
            [C. Right-Angle Traceability]
            FAIL if: the object's essential silhouette requires many diagonal or curved lines
            Otherwise: PASS
            
            Final output rule:
            - If all three are PASS → output PASS
            - If any one is FAIL → output FAIL
            
            Output only PASS or FAIL. No explanation. No other text.
            
            The object is given in Korean. Translate it to English internally before evaluating.
            Object to evaluate: \\
            """;

    private static final String IMAGE_MODEL = "gpt-4o";
    private static final String IMAGE_ESTIMATE_PROMPT = """
            You are evaluating a GPS running art image for quality and runnability.
            The image should show a neon green polygon outline on a black background.
            
            Evaluate against these criteria:
            
            [A. Closed Loop]
            FAIL if: the outline has any gaps, open ends, or disconnected segments
            FAIL if: the outline branches or crosses itself
            Otherwise: PASS
            
            [B. No Forbidden Shapes]
            FAIL if: any circle or smooth curve appears anywhere in the image
            FAIL if: any line appears inside the shape boundary
            Otherwise: PASS
            
            [C. Recognizability]
            FAIL if: the shape is unrecognizable as the given object
            FAIL if: the shape is too complex to be physically run as a route
            Otherwise: PASS
            
            Final output rule:
            - If all three are PASS → output PASS
            - If any one is FAIL → output FAIL
            
            Output only PASS or FAIL. No explanation. No other text.
            The object this image is supposed to represent: \
            """;


    public boolean estimateText(String object) {

        RequestMessage requestMessage = ChallengeConverter.toRequestMessage(
                TEXT_ESTIMATE_PROMPT + object);
        GmsTextRequest gmsTextRequest = ChallengeConverter.toGmsTextRequest(TEXT_MODEL,
                requestMessage, 0.0);

        // 확실한 검증을 위해 5번 호출
        for (int i = 0; i < 5; i++) {
            GmsTextResponse response = gmsRestClient.post()
                    .uri(TEXT_URI)
                    .body(gmsTextRequest)
                    .retrieve()
                    .body(GmsTextResponse.class);

            if (response.getChoices().get(0).getMessage().getContent().trim().equals("FAIL")) {
                log.info("평가 실패 텍스트 재생성");
                return false;
            }
        }
        return true;

    }

    public boolean estimateImage(String object, String base64Image) {

        // 평가용으로 이미지 축소
        String resized = resizeImageForEvaluation(base64Image, 256);

        // content 배열 조립 (텍스트 + 이미지)
        List<VisionContent> contents = List.of(
                VisionContent.builder()
                        .type("text")
                        .text(IMAGE_ESTIMATE_PROMPT + object)
                        .build(),
                VisionContent.builder()
                        .type("image_url")
                        .imageUrl(ImageUrl.builder()
                                .url("data:image/png;base64," + resized)
                                .build())
                        .build()
        );

        VisionRequestMessage message = VisionRequestMessage.builder()
                .role("user")
                .content(contents)
                .build();

        GmsVisionRequest request = GmsVisionRequest.builder()
                .model(IMAGE_MODEL)
                .messages(List.of(message))
                .temperature(0.0)
                .build();

        ObjectMapper mapper = new ObjectMapper();
        try {
            log.info("이미지 평가 요청 body: {}", mapper.writeValueAsString(request));
        } catch (JsonProcessingException e) {
            throw new RuntimeException(e);
        }

        for (int i = 0; i < 5; i++) {
            GmsTextResponse response = gmsRestClient.post()
                    .uri(TEXT_URI)
                    .body(request)
                    .retrieve()
                    .body(GmsTextResponse.class);

            if (response.getChoices().get(0).getMessage().getContent().trim().equals("FAIL")) {
                log.info("이미지 평가 실패 - 재생성 필요");
                return false;
            }
        }
        return true;
    }

    private String resizeImageForEvaluation(String base64Image, int size) {
        try {
            byte[] imageBytes = Base64.getDecoder().decode(base64Image);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            Thumbnails.of(new ByteArrayInputStream(imageBytes))
                    .size(size, size)
                    .outputFormat("jpeg")
                    .outputQuality(0.85)
                    .toOutputStream(baos);

            return Base64.getEncoder().encodeToString(baos.toByteArray());

        } catch (IOException e) {
            throw new RuntimeException("이미지 리사이즈 실패", e);
        }
    }
}
