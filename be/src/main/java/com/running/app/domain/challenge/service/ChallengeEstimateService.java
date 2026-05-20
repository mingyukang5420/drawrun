package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
}
