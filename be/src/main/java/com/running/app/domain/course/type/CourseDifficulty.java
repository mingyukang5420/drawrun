package com.running.app.domain.course.type;

import com.running.app.domain.course.entity.CourseDistrict;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import lombok.Getter;

@Getter
public enum CourseDifficulty {

    BEGINNER(1.0),
    EASY(1.5),
    NORMAL(2.0),
    HARD(3.0);

    private final Double weight;

    CourseDifficulty(Double weight) {
        this.weight = weight;
    }

    public static CourseDifficulty from(String value) {
        if(value == null || value.isBlank()) {
            return null;
        }

        for(CourseDifficulty difficulty : CourseDifficulty.values()) {
            if(difficulty.name().equalsIgnoreCase(value)) {
                return difficulty;
            }
        }

        throw new GeneralException(ErrorStatus.BAD_REQUEST);
    }
}
