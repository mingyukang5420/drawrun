package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageRequest;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageResponse;
import com.running.app.domain.challenge.dto.GmsImageDTO.ImageRequestBody;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChallengeImageGenerateService {

    private final RestClient gmsRestClient;
    private final ChallengeImageStorageService challengeImageStorageService;
    private final ChallengeService challengeService;

    private static final String TEXT_MODEL = "gpt-4.1-mini";
    private static final String TEXT_URI = "/api.openai.com/v1/chat/completions";
    private static final String TEXT_SYSTEM_PROMPT = """
            You output only a single Korean noun — no explanation, no punctuation, nothing else.
            
            The object must meet ALL of the following conditions:
            - Has a distinctive, recognizable SILHOUETTE that can be identified by outline shape alone
            - The entire outline forms a single continuous loop — no disconnected parts
            - NOT primarily circular or curved (no ball, coin, tire, etc.)
            - NOT composed of multiple separate parts (no glasses, no bicycle, no butterfly)
            - NOT built from repetitive parallel structures (no ladder, no fence, no bookshelf)
            - NOT recognized by surface texture or pattern rather than shape
              (avoid: 옥수수, 딸기, 파인애플, 수박, 솔방울 — their outer boundary alone looks like a generic oval)
            - Prefer objects with strong, unique outer silhouettes using mostly straight edges
            
            Each call must output a DIFFERENT object from a DIFFERENT category.
            Vary broadly — heavily favor animals, food, and nature:
            - Animals: 강아지, 고양이, 고래, 독수리, 상어, 말, 코끼리, 토끼, 공룡, 기린 ...
            - Food: 고구마, 붕어빵, 케이크, 피자, 아이스크림, 버섯 ...
            - Nature: 나무, 선인장, 산, 구름, 꽃, 번개 ...
            - Buildings: 집, 성, 피라미드, 등대, 교회 ...
            - Common objects: 기타, 왕관, 열쇠, 방패, 옷걸이, 우산 ...
            - Vehicles (occasionally): 자동차, 보트, 비행기, 기차 ...
            
            Do NOT output any of the following already-used objects: """;

    private static final String IMAGE_MODEL = "gpt-image-1.5";
    private static final String IMAGE_URI = "/api.openai.com/v1/images/generations";
    private static final String IMAGE_PROMPT = """
            Minimalist geometric polygon outline of a given object,
            drawn using only straight lines with sharp angular vertices,
            no curves allowed,
            bright neon green thick outline on pure black background,
            flat 2D side profile silhouette,
            ONLY the outer boundary silhouette — no interior lines, no windows, no wheels, no internal details,
            the outline must form a single continuous closed loop with no gaps or breaks,
            Maintain the degree of each vertex at 2 as much as possible,
            Vertices with a degree of 4 or higher are strictly prohibited,
            A vertex with a degree of 3 is allowed up to a maximum of 1.
            simple enough to be traced by a person running outdoors,
            simple vector style
            Object in Korean (translate to English and draw): """;

    private static final String IMAGE_PROMPT_EASY = """
            Minimalist geometric polygon silhouette of a given object.
            Pure black background. Bright neon green thick stroke outline only.
            Flat 2D side-view profile.
            
            CRITICAL — SINGLE CLOSED LOOP ONLY:
            Imagine drawing this shape with one pen on paper — the pen touches the paper at one point,
            traces the entire outer boundary without ever lifting, and returns exactly to the starting point.
            The result is a single closed path with no open ends, no gaps, no disconnected segments.
            Any break in the loop is a fatal error.
            
            CRITICAL — EMPTY INTERIOR:
            The inside of the shape must be completely empty black.
            No lines, no circles, no holes, no details of any kind inside the boundary. Nothing.
            
            Line style: all line segments must be strictly horizontal or vertical — no diagonal lines.
            Shape goal: capture the single most iconic outline feature that makes this object immediately recognizable.
            Simplify everything else into the plainest possible boundary.
            Sharp angular corners only — no curves, no rounded edges, no smooth arcs.
            No internal details — no eyes, no windows, no wheels, no textures.
            Simple vector icon style.
            
            Object in Korean (translate to English and draw): """;

    private static final String IMAGE_PROMPT_HARD = """
            Minimalist geometric polygon silhouette of a given object.
            Pure black background. Bright neon green thick stroke outline only.
            Flat 2D side-view profile.
            
            CRITICAL — SINGLE CLOSED LOOP ONLY:
            Imagine drawing this shape with one pen on paper — the pen touches the paper at one point,
            traces the entire outer boundary without ever lifting, and returns exactly to the starting point.
            The result is a single closed path with no open ends, no gaps, no disconnected segments.
            Any break in the loop is a fatal error.
            
            CRITICAL — EMPTY INTERIOR:
            The inside of the shape must be completely empty black.
            No lines, no circles, no holes, no details of any kind inside the boundary. Nothing.
            
            Line style: strongly prefer horizontal and vertical line segments.
            Use diagonal lines only where absolutely essential to the object's defining shape.
            Shape goal: include 2 to 3 key protrusions or indentations that make this specific object
            uniquely distinguishable — not just the category, but this exact object.
            Sharp angular corners only — no curves, no rounded edges, no smooth arcs.
            Still simple enough for a person to physically run this route outdoors.
            No internal details — no eyes, no windows, no wheels, no textures.
            Simple vector icon style.
            
            Object in Korean (translate to English and draw): """;

    private final ChallengeEstimateService challengeEstimateService;

    public String callTextModel() {

        // 지금까지 진행했던 챌린지 목록 조회 및 문자열 변환
        // (이지, 하드가 같은 주제로 생성되므로 중복 방지를 위해 이지 난이도만 조회)
        List<String> challengeAllTitle = challengeService.getChallengeAllTitle(
                ChallengeDifficulty.EASY);
        String preTitles = String.join(", ", challengeAllTitle);

        GmsTextResponse gmsTextResponse = null;

        // 평가 모델에게 PASS를 받을 때 까지 실행
        String object = null;

        boolean result = false;

        while (!result) {
            // 요청 body 조립
            RequestMessage requestMessage = ChallengeConverter.toRequestMessage(
                    TEXT_SYSTEM_PROMPT + preTitles);
            GmsTextRequest gmsTextRequest = ChallengeConverter.toGmsTextRequest(TEXT_MODEL,
                    requestMessage, 1.0);

            gmsTextResponse = gmsRestClient.post()
                    .uri(TEXT_URI)
                    .body(gmsTextRequest)
                    .retrieve()
                    .body(GmsTextResponse.class);

            object = gmsTextResponse.getChoices().get(0).getMessage().getContent();

            log.info("출력된 객체: {}", object);

            log.info("텍스트 평가 모델 호출");
            result = challengeEstimateService.estimateText(object);

            if (!result) {
                // 통과 못한 문자열 생성 금지
                preTitles = preTitles + ", " + object;
            }
        }

        return object;
    }

    public record ImageModelResult(String storedPath, String b64Json) {

    }

    // 이미지 생성에 필요한 난이도 별 body를 조립하는 메서드
    public ImageRequestBody ImageRequestBodyBuilder(String object) {

        // 요청 body 조립(easy, hard)
        GmsImageRequest easyGmsImageRequest = ChallengeConverter.toGmsImageRequest(
                IMAGE_PROMPT_EASY + object, IMAGE_MODEL, ChallengeDifficulty.EASY);
        GmsImageRequest hardGmsImageRequest = ChallengeConverter.toGmsImageRequest(
                IMAGE_PROMPT_HARD + object, IMAGE_MODEL, ChallengeDifficulty.HARD);

        return ChallengeConverter.toImageRequestBody(easyGmsImageRequest, hardGmsImageRequest);
    }

    public ImageModelResult callImageModel(GmsImageRequest requestBody) {

        // 이미지 생성 요청
        GmsImageResponse gmsImageResponse = gmsRestClient.post()
                .uri(IMAGE_URI)
                .body(requestBody)
                .retrieve()
                .body(GmsImageResponse.class);

        String b64Json = gmsImageResponse.getData().get(0).getB64Json();
        log.info("받아온 base64 문자열: {}", b64Json.substring(0, 10));

        // 이미지 디스크 저장 후 경로와 base64 원본을 함께 반환 (윤곽선 추출에 base64 필요)
        String storedPath = challengeImageStorageService.storeChallengeImage(b64Json);
        return new ImageModelResult(storedPath, b64Json);
    }

}
