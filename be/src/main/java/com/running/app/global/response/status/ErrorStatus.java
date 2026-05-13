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
    INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "401", "유효하지 않은 refresh token입니다."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "403", "금지된 요청입니다."),
    SIGNUP_CONFLICT(HttpStatus.CONFLICT, "409", "중복이 발생하였습니다."),
    MEMBER_NOT_FOUND(HttpStatus.NOT_FOUND, "404", "사용자를 찾을 수 없습니다."),
    RECORD_NOT_FOUND(HttpStatus.NOT_FOUND, "404", "러닝 기록을 찾을 수 없습니다."),
    INVALID_IMAGE_FILE(HttpStatus.BAD_REQUEST, "400", "유효하지 않은 이미지 파일입니다."),
    FILE_UPLOAD_FAILED(HttpStatus.INTERNAL_SERVER_ERROR, "500", "이미지 업로드에 실패했습니다."),
    INVALID_TRACK_IMAGE_URL(HttpStatus.BAD_REQUEST, "400", "유효하지 않은 트랙 이미지 경로입니다."),
    INVALID_RECORD_STATS_PERIOD(
            HttpStatus.BAD_REQUEST,
            "400",
            "잘못된 통계 기간 필터입니다. 허용 값 : week, month, year, all"
    ),
    COURSE_NOT_FOUND(HttpStatus.NOT_FOUND, "404", "코스를 찾을 수 없습니다."),
    INVALID_ROUTE(HttpStatus.BAD_REQUEST, "400", "뛸 수 없는 길이 포함되어 있습니다."),
    ALREADY_REGISTERED_COURSE(HttpStatus.BAD_REQUEST, "400", "등록을 완료한 코스는 삭제할 수 없습니다."),
    EDITOR_NOT_EDITABLE(HttpStatus.BAD_REQUEST, "400", "수정할 수 없는 상태의 드래프트입니다."),
    DISTRICT_NOT_FOUND(HttpStatus.NOT_FOUND, "404", "해당 위치의 구를 찾을 수 없습니다."),
    WEATHER_DATA_UNAVAILABLE(HttpStatus.SERVICE_UNAVAILABLE, "503", "날씨 데이터를 현재 사용할 수 없습니다.");

    private final HttpStatus httpStatus;
    private final String code;
    private final String message;
}
