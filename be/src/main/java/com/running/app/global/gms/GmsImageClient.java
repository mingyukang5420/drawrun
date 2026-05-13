package com.running.app.global.gms;

import com.running.app.global.gms.dto.GmsImageGenerationRequest;
import com.running.app.global.gms.dto.GmsImageGenerationResponse;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@RequiredArgsConstructor
public class GmsImageClient {

    private final RestClient gmsRestClient;

    public GmsImageGenerationResponse generateImage(GmsImageGenerationRequest request) {
        return gmsRestClient.post()
                .uri("/images/generations")
                .body(request)
                .retrieve()
                .body(GmsImageGenerationResponse.class);
    }

    public GmsImageGenerationResponse editImage(
            byte[] imageBytes,
            String fileName,
            String model,
            String prompt,
            Integer imageCount,
            String size
    ) {
        String base64Image = Base64.getEncoder().encodeToString(imageBytes);
        String dataUrl = "data:image/png;base64," + base64Image;

        Map<String, Object> body = Map.of(
                "model", model,
                "prompt", prompt,
                "n", imageCount,
                "size", size,
                "input_fidelity", "high",
                "images", List.of(
                        Map.of("image_url", dataUrl)
                )
        );

        return gmsRestClient.post()
                .uri("/images/edits")
                .body(body)
                .retrieve()
                .body(GmsImageGenerationResponse.class);
    }
}
