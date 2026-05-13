package com.running.app.domain.track.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.global.gms.GmsChatClient;
import com.running.app.global.gms.GmsImageClient;
import com.running.app.global.gms.GmsProperties;
import com.running.app.global.gms.dto.GmsChatCompletionResponse;
import com.running.app.global.gms.dto.GmsImageGenerationRequest;
import com.running.app.global.gms.dto.GmsImageGenerationResponse;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class TrackImageAiService {

    private static final DateTimeFormatter FILE_TIME_FORMAT =
            DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");

    private final GmsChatClient gmsChatClient;
    private final GmsImageClient gmsImageClient;
    private final GmsProperties gmsProperties;
    private final ObjectMapper objectMapper;

    public String buildCourseImagePrompt(String courseTitle, String courseShapeDescription) {
        return """
                Create a clean poster-style running course image.
                Keep the running route shape accurate and centered.
                Use a bright background, sporty mood, and modern map-poster composition.
                Title: %s
                Route description: %s
                """.formatted(courseTitle, courseShapeDescription);
    }

    public GmsImageGenerationResponse generateCourseImage(String prompt) {
        GmsImageGenerationRequest request = GmsImageGenerationRequest.builder()
                .model(gmsProperties.getImageModel())
                .prompt(prompt)
                .n(gmsProperties.getImageCount())
                .size(gmsProperties.getImageSize())
                .build();

        return gmsImageClient.generateImage(request);
    }

    public GmsImageGenerationResponse generateStyledCourseImage(
            byte[] routeImageBytes,
            String courseTitle,
            String inferredSubject
    ) {
        String prompt = """
        You are given a route image made of a single blue line on a white background.
        This blue line defines the exact silhouette boundary of a "%s".

        Your task:
        Fill the interior of the route shape to make it look like a "%s".
        The route line IS the outer edge of the subject — treat it as the animal/object's silhouette outline.
        Do NOT place the subject next to, behind, or floating inside the route.
        The final image must look like someone drew the "%s" shape directly using the route path as its outline.

        Rules:
        - The overall shape and proportions of the route must be fully preserved.
        - Fill the enclosed area with illustration-style colors and details of "%s".
        - The subject's body should naturally fit within and align to the route boundary.
        - Keep the background clean and simple (white or near-white).
        - No text, numbers, logos, map symbols, or UI elements.
        - Bright, clear colors. High-quality illustration style.

        Course title: %s
        Subject: %s
        """.formatted(
                inferredSubject, inferredSubject, inferredSubject,
                inferredSubject, courseTitle, inferredSubject
        );

        return gmsImageClient.editImage(
                routeImageBytes,
                "route.png",
                gmsProperties.getImageModel(),
                prompt,
                gmsProperties.getImageCount(),
                gmsProperties.getImageSize()
        );
    }

    public List<String> inferRouteSilhouetteCandidates(byte[] routeImageBytes, String courseTitle) {
        String base64Image = Base64.getEncoder().encodeToString(routeImageBytes);
        String dataUrl = "data:image/png;base64," + base64Image;

        String developerPrompt = """
        너는 러닝 경로 이미지의 전체 실루엣을 보고,
        그 외곽 형태와 가장 닮은 실제 대상을 추론하는 전문가다.

        [핵심 원칙]
        경로 선이 만드는 전체 윤곽을 하나의 닫힌 실루엣으로 인식하라.
        경로 내부의 빈 공간, 선의 굵기, 시작점/끝점 마커(초록/빨강 점)는 완전히 무시하라.
        경로가 만드는 여러 루프가 있다면, 그것을 포함한 전체 외곽 덩어리를 하나의 실루엣으로 봐라.

        [분석 절차]

        STEP 1. 전체 외곽 실루엣을 하나의 덩어리로 파악하라
        - 경로 선 전체를 감싸는 가장 바깥쪽 윤곽이 어떤 형태인가?
        - 가로세로 비율은? (납작한가 / 세로로 긴가 / 정방형에 가까운가)
        - 전체적으로 어느 방향으로 뻗어 있는가? (좌우로 긴가 / 대각선인가)

        STEP 2. 주요 덩어리와 연결 구조를 파악하라
        - 큰 덩어리가 몇 개인가? (1개 / 2개 / 3개 이상)
        - 덩어리들이 어떻게 연결되어 있는가? (넓게 이어짐 / 좁은 목으로 연결 / 완전히 분리)
        - 각 덩어리의 상대적 크기와 위치 (크다/작다, 위/아래/좌/우)

        STEP 3. 돌출부와 오목부를 파악하라
        - 바깥으로 튀어나온 부분의 개수, 위치, 형태 (뾰족한가 / 둥근가)
        - 안으로 들어간 부분의 위치와 깊이

        STEP 4. 후보를 생성하고 검증하라
        - STEP 1~3의 서술과 실제로 일치하는 대상을 생성하라
        - 각 후보를 검증: "이 대상의 그림자를 그리면 지금 실루엣과 비슷한가?"
        - NO라면 즉시 교체하라
        - 유사 범주 반복 금지 (예: 고등어·참치·연어를 동시에 제시하지 마라)

        [금지 사항]
        - 색, 배경, 지도 의미, 시작/끝 마커 기반 추론 금지
        - 내부 선 패턴만 보고 판단하는 것 금지
        - 추상어, 감상 표현, 비유 문장 금지
        - 억지 해석 금지

        [출력 규칙]
        한국어 명사 5개, 형태 적합도 높은 순.
        JSON만 반환. 설명·서문·마크다운 블록 일체 금지.
        형식: {"candidates":["후보1","후보2","후보3","후보4","후보5"]}
        """;

        String userPrompt = """
        아래 러닝 경로 이미지를 분석하라.

        [분석 대상]
        경로 선 전체가 만들어내는 외곽 실루엣 덩어리.
        내부 빈 공간, 선의 세부 꺾임, 시작/종료 마커(초록·빨강 점)는 무시하라.
        경로에 루프가 여러 개라면 전체를 하나의 실루엣으로 통합해서 봐라.

        [코스 제목 활용]
        형태 판단의 마지막 동점 처리 힌트로만 사용하라.
        형태가 맞지 않으면 제목은 무시하라.

        코스 제목: %s
        """.formatted(courseTitle);

        Map<String, Object> request = Map.of(
                "model", gmsProperties.getAnalysisModel(),
                "messages", List.of(
                        Map.of(
                                "role", "developer",
                                "content", developerPrompt
                        ),
                        Map.of(
                                "role", "user",
                                "content", List.of(
                                        Map.of(
                                                "type", "text",
                                                "text", userPrompt
                                        ),
                                        Map.of(
                                                "type", "image_url",
                                                "image_url", Map.of("url", dataUrl)
                                        )
                                )
                        )
                )
        );

        GmsChatCompletionResponse response = gmsChatClient.createChatCompletion(request);
        String content = Optional.ofNullable(response)
                .map(GmsChatCompletionResponse::getChoices)
                .filter(choices -> !choices.isEmpty())
                .map(choices -> choices.get(0))
                .map(GmsChatCompletionResponse.Choice::getMessage)
                .map(GmsChatCompletionResponse.Message::getContent)
                .orElseThrow(() -> new IllegalStateException("AI silhouette inference response is empty."));

        return parseInferenceCandidates(content);
    }

    public Path saveInferenceResultToDesktop(List<String> candidates, String title) {
        try {
            Path desktopPath = Paths.get(System.getProperty("user.home"), "Desktop");
            Files.createDirectories(desktopPath);

            String safeTitle = sanitizeFileName(title);
            String timestamp = LocalDateTime.now().format(FILE_TIME_FORMAT);
            Path outputPath = desktopPath.resolve("route-shape-" + safeTitle + "-" + timestamp + ".txt");

            String content = String.join(System.lineSeparator(), candidates);
            Files.writeString(outputPath, content);
            log.info("Route silhouette inference saved to {}", outputPath);
            return outputPath;
        } catch (IOException e) {
            throw new IllegalStateException("Failed to save silhouette inference result.", e);
        }
    }

    public String extractBase64Image(GmsImageGenerationResponse response) {
        return Optional.ofNullable(response)
                .map(GmsImageGenerationResponse::getData)
                .filter(data -> !data.isEmpty())
                .map(data -> data.get(0))
                .map(GmsImageGenerationResponse.ImageData::getB64Json)
                .orElseThrow(() -> new IllegalStateException("AI image response is empty."));
    }

    public Path saveBase64ImageToDesktop(String base64Image, String title) {
        try {
            byte[] imageBytes = Base64.getDecoder().decode(base64Image);
            Path desktopPath = Paths.get(System.getProperty("user.home"), "Desktop");
            Files.createDirectories(desktopPath);

            String safeTitle = sanitizeFileName(title);
            String timestamp = LocalDateTime.now().format(FILE_TIME_FORMAT);
            Path outputPath = desktopPath.resolve("ai-route-" + safeTitle + "-" + timestamp + ".png");

            Files.write(outputPath, imageBytes);
            log.info("AI generated route image saved to {}", outputPath);
            return outputPath;
        } catch (IOException e) {
            throw new IllegalStateException("Failed to save AI generated image.", e);
        }
    }

    private String sanitizeFileName(String title) {
        if (title == null || title.isBlank()) {
            return "untitled";
        }

        String sanitized = title.replaceAll("[^a-zA-Z0-9-_]", "_");
        return sanitized.length() > 40 ? sanitized.substring(0, 40) : sanitized;
    }

    private List<String> parseInferenceCandidates(String content) {
        try {
            String normalizedContent = extractJsonPayload(content);
            RouteShapeInferenceResponse parsed =
                    objectMapper.readValue(normalizedContent, RouteShapeInferenceResponse.class);
            if (parsed.candidates == null || parsed.candidates.isEmpty()) {
                throw new IllegalStateException("AI silhouette inference candidates are empty.");
            }
            return parsed.candidates.stream().limit(5).toList();
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to parse silhouette inference response: " + content, e);
        }
    }

    private String extractJsonPayload(String content) {
        if (content == null || content.isBlank()) {
            throw new IllegalStateException("AI silhouette inference response is blank.");
        }

        String trimmed = content.trim();
        if (trimmed.startsWith("```")) {
            int firstLineEnd = trimmed.indexOf('\n');
            if (firstLineEnd >= 0) {
                trimmed = trimmed.substring(firstLineEnd + 1).trim();
            }

            if (trimmed.endsWith("```")) {
                trimmed = trimmed.substring(0, trimmed.lastIndexOf("```")).trim();
            }
        }

        int objectStart = trimmed.indexOf('{');
        int objectEnd = trimmed.lastIndexOf('}');
        if (objectStart >= 0 && objectEnd >= objectStart) {
            return trimmed.substring(objectStart, objectEnd + 1);
        }

        return trimmed;
    }

    private static class RouteShapeInferenceResponse {
        public List<String> candidates;
    }
}
