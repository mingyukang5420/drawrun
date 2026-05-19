package com.running.app.domain.weather.type;

public enum PrecipitationType {

    NONE(0, "없음", "null"),
    RAIN(1, "비", "빗속 러닝도 매력 있어요!"),
    RAIN_SNOW(2, "비/눈", "비와 눈 사이를 달려봐요!"),
    SNOW(3, "눈", "눈길은 조심조심 달려봐요!"),
    SHOWER(4, "소나기", "소나기 지나면 달려봐요!");

    private final int code;
    private final String label;
    private final String message;

    PrecipitationType(int code, String label, String message) {
        this.code = code;
        this.label = label;
        this.message = message;
    }

    public int getCode() {
        return code;
    }

    public String getLabel() {
        return label;
    }

    public String getMessage() {
        return message;
    }

    // 기상청에서 받은 숫자 코드 → PrecipitationType enum으로 변환
    // 예: fromCode(1) → RAIN
    public static PrecipitationType fromCode(int code) {
        for (PrecipitationType type : values()) {
            if (type.code == code) {
                return type;
            }
        }
        throw new IllegalArgumentException("알 수 없는 PTY 코드: " + code);
    }
}