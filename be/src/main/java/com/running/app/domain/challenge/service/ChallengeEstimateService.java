package com.running.app.domain.challenge.service;

import com.running.app.domain.challenge.converter.ChallengeConverter;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextRequest;
import com.running.app.domain.challenge.dto.GmsTextDTO.GmsTextResponse;
import com.running.app.domain.challenge.dto.GmsTextDTO.RequestMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
@RequiredArgsConstructor
@Slf4j
public class ChallengeEstimateService {

    private final RestClient gmsRestClient;

    private static final String TEXT_MODEL = "gpt-4.1-mini";
    private static final String TEXT_URI = "/api.openai.com/v1/chat/completions";
    private static final String TEXT_ESTIMATE_PROMPT = """
            당신은 입력으로 주어진 텍스트가 과연 gps 드로잉을 통해 러닝을 할 수 있을지 텍스트의 적절성을 평가하는 모델입니다.
            응답은 반드시 기타 미사여구나 대답 없이 점수(정수)만을 출력하세요. 점, score 같은 문자열도 금지입니다.
            (금지되는 예시: 0점, 네 알겠습니다 ~~ 등) (허용되는 출력 예시: 3)
            점수는 0 ~ 10점까지로 제한하며 평가 기준은 다음과 같습니다.
            - [사용자 소구점 평가(0 ~ 2점)]: 사용자들이 주어진 객체를 보고 러닝하고 싶은 마음이 드는가?, 사람들이 충분히 긍정적으로 느낄 수 있는 객체인가?
            - [난이도 변별력 평가(0 ~ 4점)]: 해당 객체로 2D 폴리곤 이미지를 생성함에 있어서 EASY와 HARD 난이도로 충분히 분리가 가능한 변별력을 갖춘 객체인가?, 난이도에 따라 충분히 간단하게 혹은 복잡하게 그려도 거의 대부분의 사용자들이 알아볼 수 있는 객체인가?
            - [러닝 실현 가능성 평가(0 ~ 4점)]: 해당 객체로 2D 폴리곤 이미지를 생성함에 있어서 대한민국의 도보 가능한 도로 상황을 반영하여 꺾이는 부분을 충분히 직각에 가깝게 표현할 수 있는 객체인가?
            """;

    public void estimateText(String object) {

        RequestMessage requestMessage = ChallengeConverter.toRequestMessage(TEXT_ESTIMATE_PROMPT);
        GmsTextRequest gmsTextRequest = ChallengeConverter.toGmsTextRequest(TEXT_MODEL,
                requestMessage);

        GmsTextResponse response = gmsRestClient.post()
                .uri(TEXT_URI)
                .body(gmsTextRequest)
                .retrieve()
                .body(GmsTextResponse.class);

        log.info("평가 점수: {}", response.getChoices().get(0).getMessage().getContent());

    }
}
