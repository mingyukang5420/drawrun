package com.running.app.global.gms;

import com.running.app.global.gms.dto.GmsChatCompletionResponse;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
@RequiredArgsConstructor
public class GmsChatClient {

    private final RestClient gmsRestClient;

    public GmsChatCompletionResponse createChatCompletion(Map<String, Object> request) {
        return gmsRestClient.post()
                .uri("/chat/completions")
                .body(request)
                .retrieve()
                .body(GmsChatCompletionResponse.class);
    }
}
