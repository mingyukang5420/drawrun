package com.running.app.domain.record.dto;

import com.running.app.domain.track.dto.TrackRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class RecordRequest {

    @Getter
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CreateDTO {

        private Long courseId;
        private Long courseDraftId;
        private Long challengeId;
        private BigDecimal similarityScore;

        @NotBlank(message = "제목은 필수입니다.")
        @Size(max = 20, message = "제목은 20자 이하여야 합니다.")
        private String title;

        @NotNull(message = "거리는 필수입니다.")
        @Positive(message = "거리는 0보다 커야 합니다.")
        private Double distance;

        @NotBlank(message = "트랙 이미지 경로는 필수입니다.")
        private String trackImageUrl;

        @NotNull(message = "러닝 시간은 필수입니다.")
        @Positive(message = "러닝 시간은 0보다 커야 합니다.")
        private Integer runningTime;

        @NotNull(message = "평균 페이스는 필수입니다.")
        @Positive(message = "평균 페이스는 0보다 커야 합니다.")
        private Double avgPace;

        @NotNull(message = "칼로리는 필수입니다.")
        @PositiveOrZero(message = "칼로리는 0 이상이어야 합니다.")
        private Integer calories;

        @NotNull(message = "케이던스는 필수입니다.")
        @PositiveOrZero(message = "케이던스는 0 이상이어야 합니다.")
        private Integer cadence;

        @NotNull(message = "시작 시각은 필수입니다.")
        private LocalDateTime startedAt;

        @NotNull(message = "종료 시각은 필수입니다.")
        private LocalDateTime endedAt;

        @NotEmpty(message = "트랙 좌표는 최소 1개 이상 필요합니다.")
        @Valid
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
