package com.running.app.domain.run.controller;

import com.running.app.domain.run.dto.RunRequest;
import com.running.app.domain.run.dto.RunResponse;
import com.running.app.domain.run.service.RunService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Run", description = "러닝 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/run")
public class RunController {

    private final RunService runService;

    @PostMapping("/start")
    public ApiResponse<RunResponse.StartDTO> startRun(
            @RequestBody @Valid RunRequest.StartDTO request
    ) {
        RunResponse.StartDTO response = runService.startRun(request);

        return ApiResponse.onSuccess(response);
    }

}
