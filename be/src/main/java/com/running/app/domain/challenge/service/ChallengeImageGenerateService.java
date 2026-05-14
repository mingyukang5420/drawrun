package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageRequest;
import com.running.app.domain.challenge.dto.GmsImageDTO.GmsImageResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
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

    private static final String TEXT_MODEL = "gpt-4.1-mini";
    private static final String TEXT_URI = "/api.openai.com/v1/chat/completions";
    private static final String TEXT_SYSTEM_PROMPT = """
                You output only a single Korean noun — no explanation, no punctuation, nothing else.
            
                The object must meet these conditions:
                - Has a simple, recognizable side-profile silhouette
                - Large enough that its outline can be traced by running (vehicles, animals, buildings, etc.)
                - NOT too small or complex (no pencil, fork, cup, etc.)
            
                Each call must output a DIFFERENT object. Avoid repeating common ones.
                Vary across categories: vehicles, animals, buildings, nature, tools, food, etc.
            
                Example output: 자동차
            """;

    private static final String IMAGE_MODEL = "gpt-image-1.5";
    private static final String IMAGE_URI = "/api.openai.com/v1/images/generations";
    private static final String IMAGE_PROMPT = """
            Minimalist geometric polygon outline of a given object,
            drawn using only straight lines with sharp angular vertices,
            no curves allowed,
            bright neon green thick outline on pure black background,
            flat 2D side profile silhouette,
            no fill, no interior details, no shading,
            simple vector style
            Object in Korean (translate to English and draw): """;

    public String callTextModel() {

        // 요청 body 조립
        RequestMessage requestMessage = ChallengeConverter.toRequestMessage(TEXT_SYSTEM_PROMPT);
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

        // 이미지 디스크 저장 로직 호출 후 반환
        return challengeImageStorageService.storeChallengeImage(
                gmsImageResponse.getData().get(0).getB64Json());
    }

}
