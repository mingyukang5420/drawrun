package com.running.app.domain.weather.type;

public enum PrecipitationType {

    NONE(0, "없음"),
    RAIN(1, "비"),
    RAIN_SNOW(2, "비/눈"),
    SNOW(3, "눈"),
    SHOWER(4, "소나기");

    private final int code;
    private final String label;

    PrecipitationType(int code, String label) {
        this.code = code;
        this.label = label;
    }

    public int getCode() { return code; }
    public String getLabel() { return label; }

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