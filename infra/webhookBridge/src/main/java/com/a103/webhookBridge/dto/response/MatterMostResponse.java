package com.a103.webhookBridge.dto.response;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record MatterMostResponse(
        String text,
        String channel,
        List<Attachment> attachments
) {

    public MatterMostResponse(String text, List<Attachment> attachments) {
        this(text, null, attachments);
    }

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Attachment(
            String color,
            String text
    ) {

    }
}
