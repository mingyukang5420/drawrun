package com.running.app.domain.challenge.converter;

import com.running.app.domain.challenge.dto.GmsImageDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.entity.Challenge;
import java.time.LocalDateTime;
import java.util.List;

public abstract class ChallengeConverter {

    public static GmsTextRequest toGmsTextRequest(String model,
            GmsTextDTO.RequestMessage requestMessage) {

        return GmsTextRequest.builder()
                .model(model)
                .messages(List.of(requestMessage))
                .build();
    }

    public static GmsTextDTO.RequestMessage toRequestMessage(String prompt) {
        return GmsTextDTO.RequestMessage.builder()
                .role("system")
                .content(prompt)
                .build();
    }

    public static GmsImageDTO.GmsImageRequest toGmsImageRequest(String prompt, String model) {

        return GmsImageDTO.GmsImageRequest.builder()
                .model(model)
                .prompt(prompt)
                .n(1)
                .size("1024x1024")
                .outputFormat("png")
                .build();

    }

    public static Challenge toChallenge(String title, String imagePath) {

        // 14일 후 정각으로 세팅
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime end = now.plusDays(14).toLocalDate().atStartOfDay();

        return Challenge.builder()
                .title(title)
                .polygonImageUrl(imagePath)
                .startedAt(now)
                .endedAt(end)
                .build();
    }
}
