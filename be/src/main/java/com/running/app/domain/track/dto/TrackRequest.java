package com.running.app.domain.track.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

// NodeDTO 생성
public abstract class TrackRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class NodeDTO{
        @NotNull(message = "위도는 필수입니다.")
        private Double lat;

        @NotNull(message = "경도는 필수입니다.")
        private Double lng;
    }
}
