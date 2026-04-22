package com.running.app.global.response;

import com.running.app.global.response.status.ErrorStatus;
import com.running.app.global.response.status.SuccessStatus;

/**
 * 모든 API 응답의 공통 형식을 정의하는 레코드입니다.
 *
 * @param isSuccess 성공 여부 (true: 성공, false: 실패)
 * @param code      응답 상태 코드 (예: "200", "400")
 * @param message   응답 상태 메시지
 * @param result    실제 응답 데이터 (Generic)
 */
public record ApiResponse<T>(
        Boolean isSuccess,
        String code,
        String message,
        T result) {

    /**
     * 성공 응답 중 데이터가 없는 경우(Void) 사용하는 상숫값입니다.
     */
    public static final ApiResponse<Void> OK = new ApiResponse<>(
            true,
            SuccessStatus.OK.getCode(),
            SuccessStatus.OK.getMessage(),
            null);

    /**
     * 성공 시 데이터를 포함한 응답 객체를 생성합니다.
     *
     * @param result 응답할 데이터
     * @return 성공 메시지와 데이터를 포함한 ApiResponse 객체
     */
    public static <T> ApiResponse<T> onSuccess(T result) {
        return new ApiResponse<>(
                true,
                SuccessStatus.OK.getCode(),
                SuccessStatus.OK.getMessage(),
                result);
    }

    /**
     * 실패 시 에러 정보를 포함한 응답 객체를 생성합니다.
     *
     * @param errorStatus 에러 코드 정보를 담은 Enum
     * @param data        추가 에러 상세 정보
     * @return 실패 상태와 메시지를 포함한 ApiResponse 객체
     */
    public static <T> ApiResponse<T> onFailure(
            ErrorStatus errorStatus,
            T data) {
        return new ApiResponse<>(
                false,
                errorStatus.getCode(),
                errorStatus.getMessage(),
                data);
    }

}
