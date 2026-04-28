package com.running.app.domain.track.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

// NodeDTO 생성
public abstract class TrackRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class NodeDTO{
        private Double lat;
        private Double lng;
    }
}
