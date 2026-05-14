package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageRequest;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
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
            
            The object must meet these conditions:
            - Has a simple, recognizable side-profile silhouette
            - Large enough that its outline can be traced by running (vehicles, animals, buildings, etc.)
            - NOT too small or complex (no pencil, fork, cup, etc.)
            - Avoid objects that are primarily circular or curved (no ball, wheel, coin, etc.)
            - Prefer objects with mostly straight edges (vehicles, buildings, tools, etc.)
            
            Each call must output a DIFFERENT object. Avoid repeating common ones.
            Vary across categories: vehicles, animals, buildings, nature, tools, food, etc.
            
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

    public String callTextModel() {

        // 지금까지 진행했던 챌린지 목록 조회 및 문자열 변환
        List<String> challengeAllTitle = challengeService.getChallengeAllTitle();
        String preTitles = String.join(", ", challengeAllTitle);

        // 요청 body 조립
        RequestMessage requestMessage = ChallengeConverter.toRequestMessage(
                TEXT_SYSTEM_PROMPT + preTitles);
        GmsTextRequest gmsTextRequest = ChallengeConverter.toGmsTextRequest(TEXT_MODEL,
                requestMessage);

        GmsTextResponse gmsTextResponse = gmsRestClient.post()
                .uri(TEXT_URI)
                .body(gmsTextRequest)
                .retrieve()
                .body(GmsTextResponse.class);

        log.info("출력된 객체: {}", gmsTextResponse.getChoices().get(0).getMessage().getContent());

        return gmsTextResponse.getChoices().get(0).getMessage().getContent();
    }

    public String callImageModel(String object) {

        // 요청 body 조립
        GmsImageRequest gmsImageRequest = ChallengeConverter.toGmsImageRequest(
                IMAGE_PROMPT + object,
                IMAGE_MODEL);

        GmsImageResponse gmsImageResponse = gmsRestClient.post()
                .uri(IMAGE_URI)
                .body(gmsImageRequest)
                .retrieve()
                .body(GmsImageResponse.class);

        log.info("받아온 base64 문자열: {}",
                gmsImageResponse.getData().get(0).getB64Json().substring(0, 10));

        // 이미지 디스크 저장 로직 호출 후 저장 경로 반환
        return challengeImageStorageService.storeChallengeImage(
                gmsImageResponse.getData().get(0).getB64Json());
    }

}
