package com.running.app.domain.record.type;

import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;

public enum RecordStatsPeriod {

    WEEK("week"),
    MONTH("month"),
    YEAR("year"),
    ALL("all");

    private final String value;

    RecordStatsPeriod(String value) {
        this.value = value;
    }

    public static RecordStatsPeriod from(String value) {
        // 기본값 ALL
        if(value == null || value.isBlank()) {
            return ALL;
        }

        for(RecordStatsPeriod period : RecordStatsPeriod.values()) {
            // 대소문자 무시
            if(period.value.equalsIgnoreCase(value)) {
                return period;
            }
        }

        throw new GeneralException(ErrorStatus.INVALID_RECORD_STATS_PERIOD, value);
    }

}
