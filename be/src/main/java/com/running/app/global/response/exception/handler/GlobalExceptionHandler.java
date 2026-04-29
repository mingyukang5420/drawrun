package com.running.app.global.response.exception.handler;

import com.running.app.global.response.ApiResponse;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import jakarta.validation.ConstraintViolationException;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(GeneralException.class)
    public ResponseEntity<ApiResponse<Object>> handleGeneralException(GeneralException ex) {
        log.error("Error Code: {}, Message: {}, Data: {}",
                ex.getErrorStatus().getCode(),
                ex.getErrorStatus().getMessage(),
                ex.getData() != null ? ex.getData() : "No additional data",
                ex
        );

        return ResponseEntity
                .status(ex.getErrorStatus().getHttpStatus())
                .body(ApiResponse.onFailure(
                        ex.getErrorStatus(),
                        ex.getData()
                ));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Object>> handleMethodArgumentNotValidException(
            MethodArgumentNotValidException ex
    ) {
        List<String> errorMessages = getValidationErrorMessages(ex);
        log.error("Validation errors: {}", errorMessages, ex);

        return ResponseEntity
                .status(ErrorStatus.BAD_REQUEST.getHttpStatus())
                .body(ApiResponse.onFailure(
                        ErrorStatus.BAD_REQUEST,
                        errorMessages
                ));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Object>> handleConstraintViolationException(
            ConstraintViolationException ex
    ) {
        List<String> errorMessages = getValidationErrorMessages(ex);
        log.error("Validation errors: {}", errorMessages, ex);

        return ResponseEntity
                .status(ErrorStatus.BAD_REQUEST.getHttpStatus())
                .body(ApiResponse.onFailure(
                        ErrorStatus.BAD_REQUEST,
                        errorMessages
                ));
    }

    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiResponse<Object>> handleMissingServletRequestParameterException(
            MissingServletRequestParameterException ex
    ) {
        String errorMessage = ex.getParameterName() + ": 필수 파라미터가 누락되었습니다.";
        log.error("Missing parameter: {}", errorMessage, ex);

        return ResponseEntity
                .status(ErrorStatus.BAD_REQUEST.getHttpStatus())
                .body(ApiResponse.onFailure(
                        ErrorStatus.BAD_REQUEST,
                        List.of(errorMessage)
                ));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiResponse<Object>> handleDataIntegrityViolationException(
            DataIntegrityViolationException ex
    ) {

        log.error("Missing parameter: {}", ex.getMessage());

        return ResponseEntity
                .status(ErrorStatus.SIGNUP_CONFLICT.getHttpStatus())
                .body(ApiResponse.onFailure(
                        ErrorStatus.SIGNUP_CONFLICT,
                        null
                ));
    }

    private List<String> getValidationErrorMessages(MethodArgumentNotValidException ex) {
        return ex.getBindingResult().getFieldErrors().stream()
                .map(fieldError -> {
                    String field = fieldError.getField();       // 실패한 필드 이름
                    String message = fieldError.getDefaultMessage(); // 검증 실패 메시지
                    return field + ": " + message;
                })
                .toList();
    }

    private List<String> getValidationErrorMessages(ConstraintViolationException ex) {
        return ex.getConstraintViolations().stream()
                .map(violation -> {
                    String field = violation.getPropertyPath().toString(); // 위반된 필드
                    String message = violation.getMessage();              // 검증 실패 메시지
                    return field + ": " + message;
                })
                .toList();
    }
}