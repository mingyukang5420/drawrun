package com.running.app.domain.run.dto;

import com.running.app.domain.track.dto.TrackRequest;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.util.List;

public abstract class RunResponse {

    @Getter
    @Builder
    @AllArgsConstructor
    @NoArgsConstructor
    public static class StartDTO {

        List<TrackRequest.NodeDTO> nodes;
    }
}
