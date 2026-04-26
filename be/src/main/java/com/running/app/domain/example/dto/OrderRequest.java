package com.running.app.domain.example.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

public abstract class OrderRequest {

    @Getter
    @Setter
    @NoArgsConstructor
    @Schema(description = "주문 생성 요청 DTO")
    public static class CreateDTO {

        @NotBlank
        @Schema(example = "맥북 프로 16인치")
        private String productName;

        @NotNull
        @Min(1)
        @Schema(example = "1")
        private Integer quantity;

        @NotNull
        @Min(0)
        @Schema(example = "3500000")
        private Integer totalPrice;

        @NotBlank
        @Schema(example = "박성문")
        private String buyerName;

        @NotBlank
        @Schema(example = "010-1234-5678")
        private String buyerPhone;
    }
}
