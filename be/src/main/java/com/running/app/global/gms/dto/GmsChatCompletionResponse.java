package com.running.app.global.gms.dto;

import java.util.List;
import lombok.Getter;

@Getter
public class GmsChatCompletionResponse {

    private List<Choice> choices;

    @Getter
    public static class Choice {
        private Message message;
    }

    @Getter
    public static class Message {
        private String content;
    }
}
