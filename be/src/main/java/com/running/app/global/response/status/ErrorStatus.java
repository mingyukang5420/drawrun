package com.running.app.global.response.status;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ErrorStatus {
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, "500", "서버 에러, 관리자에게 문의 바랍니다."),
    BAD_REQUEST(HttpStatus.BAD_REQUEST, "400", "잘못된 요청입니다."),
    UNAUTHORIZED(HttpStatus.UNAUTHORIZED, "401", "로그인 인증이 필요합니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "403", "금지된 요청입니다."),
    SIGNUP_CONFLICT(HttpStatus.CONFLICT, "409", "중복이 발생하였습니다."),
    RECORD_NOT_FOUND(HttpStatus.NOT_FOUND,"404" ,"러닝 기록을 찾을 수 없습니다." );

    private final HttpStatus httpStatus;
    private final String code;
    private final String message;
}
