package com.running.app.domain.run.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class RunRequest {

    @Getter
    @AllArgsConstructor
    @NoArgsConstructor
    public static class StartDTO {

        Long courseId;
        Long courseDraftId;

    }
}
