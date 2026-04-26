package com.running.app.domain.example.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class OrderResponse {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "주문 상세 응답 DTO")
    public static class OrderDetailDTO {

        @Schema(example = "1")
        private Long orderId;

        @Schema(example = "맥북 프로 16인치")
        private String productName;

        @Schema(example = "1")
        private int quantity;

        @Schema(example = "3500000")
        private int totalPrice;

        @Schema(example = "PENDING")
        private String statusLabel;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @Schema(description = "주문 목록용 요약 응답 DTO")
    public static class OrderSummaryDTO {

        @Schema(example = "1")
        private Long orderId;

        @Schema(example = "맥북 프로 16인치")
        private String productName;

        @Schema(example = "PENDING")
        private String statusLabel;
    }
}
