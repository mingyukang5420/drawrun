package com.running.app.domain.challenge.converter;

import com.running.app.domain.challenge.dto.GmsDTO;
import com.running.app.domain.challenge.dto.GmsDTO.GmsTextRequest;
import java.util.List;

public abstract class ChallengeConverter {

    public static GmsTextRequest toGmsTextRequest(String model,
            GmsDTO.RequestMessage requestMessage) {

        return GmsTextRequest.builder()
                .model(model)
                .messages(List.of(requestMessage))
                .build();
    }

    public static GmsDTO.RequestMessage toRequestMessage(String prompt) {
        return GmsDTO.RequestMessage.builder()
                .role("system")
                .content(prompt)
                .build();
    }
}
