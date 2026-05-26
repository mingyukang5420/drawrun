package com.running.app.domain.challenge.dto;

import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class GmsTextDTO {

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GmsTextRequest {

        private String model;
        private List<RequestMessage> messages;
        private Double temperature;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RequestMessage {

        private String role;
        private String content;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class GmsTextResponse {

        private List<Choice> choices;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Choice {

        private ResponseMessage message;
    }

    @Getter
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ResponseMessage {

        private String content;
    }
}
