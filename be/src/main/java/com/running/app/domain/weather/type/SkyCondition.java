package com.running.app.domain.weather.type;

public enum SkyCondition {

    CLEAR(1, "맑음", "오늘은 뛰기 정말 좋은 날이에요!"),
    CLOUDY(3, "구름많음", "구름이 많지만 달리기엔 문제없어요!"),
    OVERCAST(4, "흐림", "흐린 날도 달리면 기분이 맑아져요!");

    private final int code;
    private final String label;
    private final String message;

    SkyCondition(int code, String label, String message) {
        this.code = code;
        this.label = label;
        this.message = message;
    }

    public int getCode() { return code; }
    public String getLabel() { return label; }
    public String getMessage() { return message; }

    // 기상청에서 받은 숫자 코드 → SkyCondition enum으로 변환
    // 예: fromCode(1) → CLEAR
    public static SkyCondition fromCode(int code) {
        for (SkyCondition sky : values()) {
            if (sky.code == code) {
                return sky;
            }
        }
        throw new IllegalArgumentException("알 수 없는 SKY 코드: " + code);
    }
}