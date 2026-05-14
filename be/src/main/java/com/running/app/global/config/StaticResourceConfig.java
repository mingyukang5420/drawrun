package com.running.app.global.config;

import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

// Spring MVC 설정을 커스터마이징 하기 위해 implements
@Configuration
public class StaticResourceConfig implements WebMvcConfigurer {
    // 저장된 파일을 URL로 접근 가능하게 하는 설정
    // URL 경로와 디스크 폴더 연결

    private final String trackImageDir;
    private final String trackImagePathPrefix;
    private final String contextPath;

    private final String challengeImageDir;
    private final String challengeImagePathPrefix;

    public StaticResourceConfig(
            // 실제 저장 폴더
            @Value("${app.upload.track-image-dir}") String trackImageDir,
            // 공개 URL prefix
            @Value("${app.upload.track-image-path-prefix}") String trackImagePathPrefix,
            @Value("${server.servlet.context-path:}") String contextPath,
            // 챌린지 관련 경로
            @Value("${app.upload.challenge-image-dir}") String challengeImageDir,
            @Value("${app.upload.challenge-image-path-prefix}") String challengeDirPrefix
    ) {
        this.trackImageDir = trackImageDir;
        this.trackImagePathPrefix = trackImagePathPrefix;
        this.contextPath = normalizeContextPath(contextPath);
        this.challengeImageDir = challengeImageDir;
        this.challengeImagePathPrefix = challengeDirPrefix;
    }

    // 해당 URL로 오면 폴더의 파일을 보여주도록 등록
    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        String handlerPattern = createHandlerPattern(trackImagePathPrefix);
        String resourceLocation = createResourceLocation(trackImageDir);

        registry.addResourceHandler(handlerPattern)
                .addResourceLocations(resourceLocation);

        // 챌린지 경로 추가
        registry.addResourceHandler(createHandlerPattern(challengeImagePathPrefix))
                .addResourceLocations(createResourceLocation(challengeImageDir));
    }

    // 브라우저가 접근할 URL 패턴 생성
    private String createHandlerPattern(String urlPrefix) {
        String normalizedPrefix = normalizeUrlPrefix(urlPrefix);

        if (!contextPath.isEmpty() && normalizedPrefix.startsWith(contextPath + "/")) {
            normalizedPrefix = normalizedPrefix.substring(contextPath.length());
        }

        return normalizedPrefix + "/**";
    }

    // 실제 서버 경로를 URI 형태로 변경
    private String createResourceLocation(String uploadDir) {
        Path normalizedPath = Paths.get(uploadDir).toAbsolutePath().normalize();
        return normalizedPath.toUri().toString();
    }

    // prefix 정리
    private String normalizeUrlPrefix(String urlPrefix) {
        String normalized = urlPrefix.trim();

        if (!normalized.startsWith("/")) {
            normalized = "/" + normalized;
        }

        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }

    private String normalizeContextPath(String contextPath) {
        if (contextPath == null || contextPath.isBlank()) {
            return "";
        }

        String normalized = contextPath.trim();

        if (!normalized.startsWith("/")) {
            normalized = "/" + normalized;
        }

        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }
}
