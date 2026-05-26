package com.a103.webhookBridge.dto.response;

import com.a103.webhookBridge.dto.response.status.SuccessStatus;

public record ApiResponse<T>(
        Boolean isSuccess,
        String code,
        String message,
        T result) {

    public static final ApiResponse<Void> OK = new ApiResponse<>(
            true,
            SuccessStatus.OK.getCode(),
            SuccessStatus.OK.getMessage(),
            null);
}
