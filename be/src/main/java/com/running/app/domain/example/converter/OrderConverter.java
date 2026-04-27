package com.running.app.domain.example.converter;

import com.running.app.domain.example.dto.OrderResponse;
import com.running.app.domain.example.entity.Order;
import com.running.app.domain.example.entity.OrderStatus;

public abstract class OrderConverter {

    /**
     * 외부 데이터 → Entity
     * 사용 시점: 주문 생성
     */
    public static Order toOrder(String productName, int quantity, int totalPrice,
            String buyerName, String buyerPhone) {
        return Order.builder()
                .productName(productName)
                .quantity(quantity)
                .totalPrice(totalPrice)
                .buyerName(buyerName)
                .buyerPhone(buyerPhone)
                .status(OrderStatus.PENDING)
                .build();
    }

    /**
     * Entity → 상세 응답 DTO
     * 사용 시점: 주문 상세 조회 API
     */
    public static OrderResponse.OrderDetailDTO toOrderDetailDTO(Order order) {
        return OrderResponse.OrderDetailDTO.builder()
                .orderId(order.getId())
                .productName(order.getProductName())
                .quantity(order.getQuantity())
                .totalPrice(order.getTotalPrice())
                .statusLabel(order.getStatus().name())
                .build();
    }

    /**
     * Entity → 요약 응답 DTO
     * 사용 시점: 주문 목록 조회 API
     */
    public static OrderResponse.OrderSummaryDTO toOrderSummaryDTO(Order order) {
        return OrderResponse.OrderSummaryDTO.builder()
                .orderId(order.getId())
                .productName(order.getProductName())
                .statusLabel(order.getStatus().name())
                .build();
    }
}
