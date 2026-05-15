package com.running.app.domain.challenge.converter;

import com.running.app.domain.challenge.dto.GmsImageDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.entity.Challenge;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.time.temporal.TemporalAdjusters;
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

        LocalDateTime now = LocalDateTime.now();

        // 시작일과 무관하게 다음주 월요일로 끝나는 날 지정
        LocalDateTime end = LocalDateTime.now()
                .with(TemporalAdjusters.next(DayOfWeek.MONDAY))
                .toLocalDate()
                .atStartOfDay();

        return Challenge.builder()
                .title(title)
                .polygonImageUrl(imagePath)
                .startedAt(now)
                .endedAt(end)
                .build();
    }

}
