package com.running.app.domain.editor.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
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

    // 에디터 저장 요청 — 사용자가 그린 코스(제목 + 좌표 시퀀스)
    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SaveRequest {

        @NotBlank(message = "제목은 빈 값일 수 없습니다.")
        @Size(max = 20, message = "제목은 20자 이하여야 합니다.")
        private String title;

        @NotEmpty(message = "좌표는 빈 값일 수 없습니다.")
        @Size(min = 2, message = "좌표는 최소 2개 이상이어야 합니다.")
        @Valid
        private List<NodeDTO> coordinates;

        // data URI 형식 — "data:image/png;base64,..." 또는 "data:image/jpeg;base64,..."
        @NotBlank(message = "썸네일은 빈 값일 수 없습니다.")
        private String thumbnailBase64;

        @Getter
        @NoArgsConstructor
        @AllArgsConstructor
        public static class NodeDTO {

            @NotNull(message = "위도는 빈 값일 수 없습니다.")
            private Double lat;

            @NotNull(message = "경도는 빈 값일 수 없습니다.")
            private Double lng;

            @NotNull(message = "순서는 빈 값일 수 없습니다.")
            @Min(value = 1, message = "순서는 1 이상이어야 합니다.")
            private Integer order;
        }
    }
}
