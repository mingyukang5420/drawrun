package com.running.app.domain.editor.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * editor 관련 요청을 받아 서빙하는 dto
 */
public abstract class EditorRequest {

    @Getter
    @Builder
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    @NoArgsConstructor(access = AccessLevel.PUBLIC)
    public static class WayRequest {

        // Lat: 위도, Lng: 경도

        @NotNull(message = "빈 값일 수 없습니다.")
        private Double minLat;
        @NotNull(message = "빈 값일 수 없습니다.")
        private Double minLng;
        @NotNull(message = "빈 값일 수 없습니다.")
        private Double maxLat;
        @NotNull(message = "빈 값일 수 없습니다.")
        private Double maxLng;
        @NotNull(message = "빈 값일 수 없습니다.")
        private Integer zoom;
    }
}
