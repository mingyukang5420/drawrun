package com.running.app.domain.course.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class CourseRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChangeTitleDTO {

        @NotBlank(message = "코스 제목은 필수입니다.")
        @Size(max = 20, message = "코스 제목은 20자 이하여야 합니다.")
        private String title;
    }
}
