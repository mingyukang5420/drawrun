package com.running.app.domain.challenge.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.running.app.domain.challenge.type.ChallengeDifficulty;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class GmsImageDTO {


    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GmsImageRequest {

        private String model;
        private String prompt;
        private int n;
        private String size;
        @JsonProperty("output_format")
        private String outputFormat;

        @JsonIgnore
        private ChallengeDifficulty difficulty;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GmsImageResponse {

        private List<ImageData> data;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ImageData {

        @JsonProperty("b64_json")
        private String b64Json;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ImageRequestBody {

        private GmsImageRequest easyImageBody;
        private GmsImageRequest hardImageBody;
    }

}
