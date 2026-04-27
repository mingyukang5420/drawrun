package com.a103.webhookBridge.client;

import com.a103.webhookBridge.dto.response.MatterMostResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
@RequiredArgsConstructor
@Slf4j
public class MatterMostClient {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${notification.mattermost.gitlab-webhook-url}")
    private String mrWebhookUrl;

    public void mrSendMessage(MatterMostResponse payload) {
        try {
            restTemplate.postForEntity(mrWebhookUrl, payload, String.class);
        } catch (Exception e) {
            log.error("[Mattermost] MR 메시지 전송 실패 : " + e.getMessage());
        }
    }
}
