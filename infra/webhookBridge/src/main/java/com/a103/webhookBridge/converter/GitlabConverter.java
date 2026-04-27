package com.a103.webhookBridge.converter;

import com.a103.webhookBridge.dto.request.GitlabRequest;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Gitlab에서 수신된 데이터를 마크다운 형식으로 변환하는 컨버터입니다.
 */
@Component
@Slf4j
public class GitlabConverter {

    // Gitlab name을 MM ID(@userid)로 매핑
    private Map<String, String> userMap;
    // Label을 담당자 MM ID(@userid)로 매핑
    private Map<String, List<String>> labelMap;

    /**
     * 환경 변수에 설정된 JSON 문자열을 파싱하여 매핑 테이블을 초기화합니다.
     */
    public GitlabConverter(
            @Value("${notification.user-mapping}") String userJson,
            @Value("${notification.label-mapping}") String labelJson) {
        try {
            ObjectMapper mapper = new ObjectMapper();
            this.userMap = mapper.readValue(userJson, new TypeReference<Map<String, String>>() {
            });
            this.labelMap = mapper.readValue(labelJson,
                    new TypeReference<Map<String, List<String>>>() {
                    });
        } catch (Exception e) {
            this.userMap = new HashMap<>();
            this.labelMap = new HashMap<>();
        }
    }

    /**
     * 수신한 이벤트 종류에 맞는 마크다운 컨버터 함수를 호출합니다.
     * <p>
     * Merge 같은 경우는 MR의 액션 상태중 하나로 MR의 액션 종류가 Merge인지 별도로 확인합니다. 또한 값의 변동(edit, update)이 발생할 때 마다
     * Webhook를 호출하는 문제를 해결하기 위하여 action이 open 인지 확인합니다. 그 외의 모든 요청은 null로 처리합니다.
     * <p>
     * Push 또한 develop, master 등에 push하는 경우와, A Branch -> B Branch로 push 하는 경우에만 event를 발생합니다.
     */
    public String convert(GitlabRequest request) {
        return switch (request.objectKind()) {
            case "merge_request" -> {
                if ("merge".equals(request.attributes().action())) {
                    yield createMergeMarkdown(request);
                } else if ("open".equals(request.attributes().action())) {
                    yield createMrMarkdown(request);
                }
                yield null;
            }
            case "push" -> {
                String zeroHash = "0000000000000000000000000000000000000000";
                if (zeroHash.equals(request.before()) || zeroHash.equals(request.after())) {
                    yield null;
                }
                if (!"refs/heads/develop".equals(request.ref()) && !"refs/heads/master".equals(
                        request.ref())) {
                    yield null;
                }
                yield createPushMarkdown(request);
            }
            default -> null;
        };
    }

    /**
     * MR 관련 마크다운을 생성합니다. Label의 종류에 따라 담당 인원들 전원을 멘션합니다. BE / FE / AI / INFRA
     */
    private String createMrMarkdown(GitlabRequest request) {
        var attr = request.attributes();
        String labelList = convertLabelToString(request);

        if (labelList.isEmpty()) {
            labelList = "없음";
        }
        return String.format(
                "### :pushpin: **Merge Request**\n" +
                        "- **MR 제목**: [%s](%s)\n" +
                        "- **작성자**: @%s \n" +
                        "- **Label**: %s\n" +
                        "- **상태**: %s\n" +
                        "%s\n",
                attr.title(), attr.url(),
                getConvertedTag(request),
                labelList,
                attr.state(),
                convertLabelToMention(request)
        );
    }

    /**
     * Merge 이벤트 발생 시 마크다운을 생성합니다.
     */
    private String createMergeMarkdown(GitlabRequest request) {
        var attr = request.attributes();
        return String.format(
                "### :o: **Merge Completed!**\n" +
                        "- **MR 제목**: [%s](%s)\n" +
                        "- **승인자**: @%s\n" +
                        "- **브랜치 변화**: `%s` ➔ `%s`\n" +
                        "- **상태**: merged\n",
                attr.title(), attr.url(),
                getConvertedTag(request),
                attr.sourceBranch(), attr.targetBranch()
        );
    }

    /**
     * Push 이벤트 발생 시 커밋 내역을 포함한 마크다운을 생성합니다.
     */
    private String createPushMarkdown(GitlabRequest request) {
        String commitDetails = request.commits().stream()
                .map(commit -> {
                    String shortHash = commit.id() != null ? commit.id().substring(0, 8) : "";
                    // 커밋 메시지의 첫 줄만 추출
                    String message = commit.message().split("\n")[0];
                    return String.format("- `%s`: %s - %s", shortHash, message,
                            commit.author().name());
                })
                .collect(Collectors.joining("\n"));
        String branch =
                (request.ref() != null) ? request.ref().replace("refs/heads/", "") : "unknown";
        return String.format(
                "### :white_check_mark: **Push Completed!**\n" +
                        "- **진행자**: @%s\n\n" +
                        "- **브랜치**: `%s`\n" +
                        "---\n" +
                        "**커밋 내역:**\n%s",
                getConvertedTag(request),
                branch,
                commitDetails
        );
    }

    /**
     * MR에 붙은 Label을 기준으로 담당자들을 @MMuserId 형태로 변환합니다.
     */
    private String convertLabelToMention(GitlabRequest request) {
        log.info("----- MR에 해당되는 담당자 Mention -----");
        Set<String> mentionSet = new HashSet<>();
        
        for (GitlabRequest.Label label : request.labels()) {
            String labelTitle = label.title();

            if (labelMap.containsKey(labelTitle)) {
                List<String> assignees = labelMap.get(labelTitle);
                for (String name : assignees) {
                    String mentionId = userMap.getOrDefault(name, name);
                    mentionSet.add("@" + mentionId);
                    log.info(mentionId);
                }
            }
        }
        return String.join(" ", mentionSet);
    }

    /**
     * Label을 마크다운에 표기시 보기 쉽게하기 위해서 구조를 변환합니다.
     */
    private String convertLabelToString(GitlabRequest request) {
        return request.labels().stream()
                .map(label -> "`" + label.title() + "`")
                .collect(Collectors.joining(", "));
    }

    /**
     * Gitlab의 다양한 사용자 필드에서 유효한 이름을 추출하고 매핑 테이블을 거쳐 최종 태그용 ID를 반환합니다.
     */
    private String getConvertedTag(GitlabRequest request) {
        String name = "Unknown";

        if (request.user() != null && request.user().name() != null) {
            name = request.user().name();
        } else if (request.userName() != null) {
            name = request.userName();
        } else if (request.userUsername() != null) {
            name = request.userUsername();
        }

        return userMap.getOrDefault(name, name);
    }
}