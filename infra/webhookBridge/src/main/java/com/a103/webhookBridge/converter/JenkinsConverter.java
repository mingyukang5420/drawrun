package com.a103.webhookBridge.converter;

import com.a103.webhookBridge.dto.request.JenkinsRequest;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class JenkinsConverter {

    // Gitlab name을 MM ID(멘션용)으로 매핑
    private Map<String, String> userMap;

    private final String internalUrl;
    private final String publicUrl;

    // 환경 변수에 설정된 JSON 문자열을 파싱하여 매핑 테이블을 초기화
    public JenkinsConverter(
            @Value("${notification.user-mapping}") String userJson,
            @Value("${notification.jenkins.internal-url-prefix}") String internalUrl,
            @Value("${notification.jenkins.public-url-prefix}") String publicUrl
    ) {
        try {
            ObjectMapper mapper = new ObjectMapper();
            this.userMap = mapper.readValue(userJson, new TypeReference<Map<String, String>>() {
            });
        } catch (Exception e) {
            this.userMap = new HashMap<>();
        } finally {
            this.internalUrl = internalUrl;
            this.publicUrl = publicUrl;
        }

    }

    public String convert(JenkinsRequest request) {
        return switch (request.status()) {
            case "STARTED" -> createStartedMarkdown(request);
            case "SUCCESS" -> createSuccessMarkdown(request);
            case "UNSTABLE" -> createUnstableMarkdown(request);
            case "FAILURE" -> createFailureMarkdown(request);
            default -> null;
        };
    }

    // 빌드/배포 시작
    private String createStartedMarkdown(JenkinsRequest request) {
        return String.format(
                "### :arrow_forward: **Build Started**\n" +
                        "- **Job**: [%s #%d](%s)\n" +
                        "- **시작 시간**: %s\n" +
                        "%s",
                request.jobName(), request.buildNumber(), convertBuildUrl(request.buildUrl()),
                request.startTime(),
                buildMrSection(request)
        );
    }

    // 빌드/배포 성공
    private String createSuccessMarkdown(JenkinsRequest request) {
        return String.format(
                "### :white_check_mark: **Build Succeeded**\n" +
                        "- **Job**: [%s #%d](%s)\n" +
                        "- **종료 시간**: %s (소요 %s)\n" +
                        "%s%s",
                request.jobName(), request.buildNumber(), convertBuildUrl(request.buildUrl()),
                request.endTime(), request.duration(),
                buildMrSection(request),
                buildTestSection(request)
        );
    }

    // 빌드/배포 UNSTABLE
    private String createUnstableMarkdown(JenkinsRequest request) {
        String authorMention = resolveMrAuthorMention(request);
        return String.format(
                "### :warning: **Build Unstable**\n" +
                        "- **Job**: [%s #%d](%s)\n" +
                        "- **종료 시간**: %s (소요 %s)\n" +
                        "%s%s\n" +
                        "%s",
                request.jobName(), request.buildNumber(), convertBuildUrl(request.buildUrl()),
                request.endTime(), request.duration(),
                buildMrSection(request),
                buildTestSection(request),
                authorMention.isEmpty() ? "" : authorMention + " 테스트 결과 확인 부탁드립니다."
        );
    }

    // 빌드/배포 실패
    private String createFailureMarkdown(JenkinsRequest request) {
        String mentions = buildFailureMentions(request);
        return String.format(
                "### :no_entry: **Build Failed**\n" +
                        "- **Job**: [%s #%d](%s)\n" +
                        "- **종료 시간**: %s (소요 %s)\n" +
                        "%s%s\n" +
                        "%s",
                request.jobName(), request.buildNumber(), convertBuildUrl(request.buildUrl()),
                request.endTime(), request.duration(),
                buildMrSection(request),
                buildTestSection(request),
                mentions.isEmpty() ? "" : mentions + " 빌드 실패 확인 부탁드립니다."
        );
    }

    // 빌드 정보 추출
    private String buildMrSection(JenkinsRequest request) {
        var mr = request.mr();
        var commit = request.commit();
        String commitShort =
                (commit != null && commit.shortHash() != null) ? commit.shortHash() : "-";

        if (mr == null || mr.iid() == null || mr.iid().isBlank()) {
            return String.format("- **커밋**: `%s`\n", commitShort);
        }

        String displayName = resolveDisplayName(mr);
        String authorTag = userMap.getOrDefault(displayName, displayName);

        return String.format(
                "- **MR**: [!%s %s](%s)\n" +
                        "- **작성자**: @%s\n" +
                        "- **브랜치**: `%s` ➔ `%s`\n" +
                        "- **커밋**: `%s`\n",
                mr.iid(), mr.title(), mr.url(),
                authorTag,
                mr.source(), mr.target(),
                commitShort
        );
    }

    // 테스트 결과
    private String buildTestSection(JenkinsRequest request) {
        var test = request.testSummary();
        if (test == null || test.total() == null || test.total() == 0) {
            return "";
        }
        return String.format(
                "- **테스트**: 통과 %d / 실패 %d / 스킵 %d (총 %d, 신규 실패 %d건)\n",
                nullToZero(test.passed()),
                nullToZero(test.failed()),
                nullToZero(test.skipped()),
                test.total(),
                nullToZero(test.newFailures())
        );
    }

    // 실패 멘션 대상자 추출
    private String buildFailureMentions(JenkinsRequest request) {
        List<String> mentions = new ArrayList<>();
        mentions.add("@" + userMap.getOrDefault("박성문", "박성문"));
        mentions.add("@" + userMap.getOrDefault("신윤수", "신윤수"));
        String authorMention = resolveMrAuthorMention(request);
        if (!authorMention.isEmpty() && !mentions.contains(authorMention)) {
            mentions.add(authorMention);
        }
        return String.join(" ", mentions);
    }

    // 멘션 대상자를 MM @userID 형태로 매핑
    private String resolveMrAuthorMention(JenkinsRequest request) {
        var mr = request.mr();
        if (mr == null) {
            return "";
        }

        String displayName = resolveDisplayName(mr);
        if ("Unknown".equals(displayName)) {
            return "";
        }

        String mentionId = userMap.getOrDefault(displayName, displayName);
        return "@" + mentionId;
    }

    // 빌드 URL Converter
    private String convertBuildUrl(String baseUrl) {
        if (baseUrl.startsWith(internalUrl)) {
            return baseUrl.replace(internalUrl, publicUrl);
        }
        return baseUrl;
    }

    // GitlabConverter.getConvertedTag와 동일한 로직
    private String resolveDisplayName(JenkinsRequest.MergeRequestInfo mr) {
        if (mr.username() != null && !mr.username().isBlank()) {
            return mr.username();
        }
        if (mr.author() != null && !mr.author().isBlank()) {
            return mr.author();
        }
        return "Unknown";
    }

    private int nullToZero(Integer value) {
        return value == null ? 0 : value;
    }

}
