package com.running.app.domain.challenge.dto;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonInclude.Include;
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

        @JsonIgnore
        private String object;
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


    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class VisionRequestMessage {

        private String role;
        private List<VisionContent> content;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(Include.NON_NULL)
    public static class VisionContent {

        private String type;      // "text" or "image_url"
        private String text;      // type=text일 때

        @JsonProperty("image_url")
        private ImageUrl imageUrl; // type=image_url일 때
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ImageUrl {

        private String url;  // "data:image/png;base64,{base64문자열}" or "https://..."
    }

    // 이미지 평가용 요청 body
    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class GmsVisionRequest {

        private String model;
        private List<VisionRequestMessage> messages;
        private Double temperature;
    }
}
