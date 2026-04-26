package com.running.app.domain.example.service;

import com.running.app.domain.example.converter.OrderConverter;
import com.running.app.domain.example.dto.OrderRequest;
import com.running.app.domain.example.dto.OrderResponse;
import com.running.app.domain.example.entity.Order;
import com.running.app.domain.example.repository.OrderRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class OrderService {

    private final OrderRepository orderRepository;

    @Transactional
    public OrderResponse.OrderDetailDTO createOrder(OrderRequest.CreateDTO request) {
        Order order = OrderConverter.toOrder(
                request.getProductName(),
                request.getQuantity(),
                request.getTotalPrice(),
                request.getBuyerName(),
                request.getBuyerPhone()
        );
        orderRepository.save(order);
        return OrderConverter.toOrderDetailDTO(order);
    }

    public OrderResponse.OrderDetailDTO getOrderDetail(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));
        return OrderConverter.toOrderDetailDTO(order);
    }

    public List<OrderResponse.OrderSummaryDTO> getOrderList() {
        return orderRepository.findAll().stream()
                .map(OrderConverter::toOrderSummaryDTO)
                .toList();
    }

    @Transactional
    public OrderResponse.OrderDetailDTO cancelOrder(Long orderId) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new GeneralException(ErrorStatus.BAD_REQUEST));
        order.cancel();
        return OrderConverter.toOrderDetailDTO(order);
    }
}
