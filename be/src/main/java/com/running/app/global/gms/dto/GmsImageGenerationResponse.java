package com.running.app.global.gms.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;
import lombok.Getter;

@Getter
public class GmsImageGenerationResponse {

    private List<ImageData> data;

    @Getter
    public static class ImageData {

        @JsonProperty("b64_json")
        private String b64Json;

        private String url;
    }
}
