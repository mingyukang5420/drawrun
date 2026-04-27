package com.a103.webhookBridge.service;

import com.a103.webhookBridge.client.MatterMostClient;
import com.a103.webhookBridge.converter.GitlabConverter;
import com.a103.webhookBridge.dto.request.GitlabRequest;
import com.a103.webhookBridge.dto.response.MatterMostResponse;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * 이벤트를 가공하여 MM에 마크다운 형식으로 전달하는 서비스 레이어입니다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WebhookService {

    // 알림을 보낼 MM 채널 이름 ( gitlab용 )
    @Value("${notification.mattermost.gitlab-channel}")
    private String gitlabChannel;

    private final GitlabConverter gitlabConverter;
    private final MatterMostClient mattermostClient;

    /**
     * Gitlab 웹훅 데이터를 처리하여 마크다운 형식 메시지를 생성하고 전송합니다.
     *
     * @param request 수신된 원본 데이터 객체
     */
    public void processGitlab(GitlabRequest request) {
        String markdown = gitlabConverter.convert(request);
        if (markdown == null) {
            String actionValue = null;
            if (request.attributes() != null) {
                actionValue = request.attributes().action();
            }
            log.warn("[Bridge Server - GitLab Service] {} / {}", request.objectKind(), actionValue);
            return;
        }

        String color = switch (request.objectKind()) {
            case "push" -> "#2196F3";
            case "merge_request" -> {
                if ("merge".equals(request.attributes().action())) {
                    yield "#008000";
                }
                yield "#FF9800";
            }
            default -> "#808080";
        };

        //MM의 Attachment 첨부 레이아웃 구조 생성
        MatterMostResponse.Attachment attachment = new MatterMostResponse.Attachment(color,
                markdown);
        // 첫 번째 인자(text)는 빈 문자열로 두어 Attachment 위주의 깔끔한 디자인 유지
        MatterMostResponse payload = new MatterMostResponse("", gitlabChannel,
                List.of(attachment));
        mattermostClient.mrSendMessage(payload);
    }
}

