package com.running.app.domain.example.controller;

import com.running.app.domain.example.dto.OrderRequest;
import com.running.app.domain.example.dto.OrderResponse;
import com.running.app.domain.example.service.OrderService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@RequestMapping("/example/orders")
@Tag(name = "OrderController", description = "Converter 컨벤션 예시용 주문 API")
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    @Operation(summary = "주문 생성")
    public ApiResponse<OrderResponse.OrderDetailDTO> createOrder(
            @Valid @RequestBody OrderRequest.CreateDTO request
    ) {
        return ApiResponse.onSuccess(orderService.createOrder(request));
    }

    @GetMapping("/{orderId}")
    @Operation(summary = "주문 상세 조회")
    public ApiResponse<OrderResponse.OrderDetailDTO> getOrderDetail(
            @PathVariable Long orderId
    ) {
        return ApiResponse.onSuccess(orderService.getOrderDetail(orderId));
    }

    @GetMapping
    @Operation(summary = "주문 목록 조회")
    public ApiResponse<List<OrderResponse.OrderSummaryDTO>> getOrderList() {
        return ApiResponse.onSuccess(orderService.getOrderList());
    }

    @PatchMapping("/{orderId}/cancel")
    @Operation(summary = "주문 취소")
    public ApiResponse<OrderResponse.OrderDetailDTO> cancelOrder(
            @PathVariable Long orderId
    ) {
        return ApiResponse.onSuccess(orderService.cancelOrder(orderId));
    }
}
