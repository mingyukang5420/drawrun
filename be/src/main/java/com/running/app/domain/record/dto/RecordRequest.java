package com.running.app.domain.record.dto;

import com.running.app.domain.track.dto.TrackRequest;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

public abstract class RecordRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateDTO {

        private Long courseId;
        private String title;
        private Double distance;
        private String trackImageUrl;
        private Integer runningTime;
        private Double avgPace;
        private Integer calories;
        private Integer cadence;
        private LocalDateTime startedAt;
        private LocalDateTime endedAt;
        private List<TrackRequest.NodeDTO> nodes;
    }

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChangeTitleDTO {

        @NotBlank(message = "제목은 필수입니다.")
        @Size(max = 20, message = "제목은 20자 이하여야 합니다.")
        private String title;
    }

}
