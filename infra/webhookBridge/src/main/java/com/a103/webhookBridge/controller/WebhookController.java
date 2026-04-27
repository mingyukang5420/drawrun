package com.a103.webhookBridge.controller;

import com.a103.webhookBridge.dto.request.GitlabRequest;
import com.a103.webhookBridge.dto.response.ApiResponse;
import com.a103.webhookBridge.service.WebhookService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Slf4j
@RequestMapping("/infra/webhook")
@RequiredArgsConstructor
public class WebhookController {

    private final WebhookService webhookService;

    @PostMapping("/gitlab")
    public ApiResponse<Void> handleGitlab(
            @RequestBody GitlabRequest request
    ) {
        webhookService.processGitlab(request);
        return ApiResponse.OK;
    }
}
