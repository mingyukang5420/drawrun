package com.running.app.domain.track.service;

import com.running.app.domain.track.dto.TrackImageResponse;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Base64;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Slf4j
@Service
public class TrackImageStorageService {
    //검증, UUID 변환, 파일저장, 공개 경로 생성

    // 업로드 가능한 타입 제한
    private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
            "image/png",
            "image/jpeg"
    );
    // 업로드 가능한 확장자 제한
    private static final List<String> ALLOWED_EXTENSIONS = List.of(".png", ".jpg", ".jpeg");

    // base64 입력은 data URI 형식만 허용 — prefix 로 mime type 구분
    private static final String DATA_URI_PNG_PREFIX = "data:image/png;base64,";
    private static final String DATA_URI_JPEG_PREFIX = "data:image/jpeg;base64,";

    private final Path trackImageDirectory;
    private final String trackImagePathPrefix;
    private final String trackImagePublicBaseUrl;

    public TrackImageStorageService(
            @Value("${app.upload.track-image-dir}") String trackImageDir,
            @Value("${app.upload.track-image-path-prefix}") String trackImagePathPrefix,
            @Value("${app.upload.track-image-public-base-url}") String trackImagePublicBaseUrl
    ) {
        this.trackImageDirectory = Paths.get(trackImageDir).toAbsolutePath().normalize();
        this.trackImagePathPrefix = normalizePathPrefix(trackImagePathPrefix);
        this.trackImagePublicBaseUrl = normalizeBaseUrl(trackImagePublicBaseUrl);
    }

    // 저장 메서드
    public TrackImageResponse store(MultipartFile imageFile) {
        validateImageFile(imageFile);

        //UUID 변환 로직
        //확장자까지 붙여 저장 파일 명을 UUID기반으로 생성
        String extension = extractExtension(imageFile.getOriginalFilename());
        String storedFileName = UUID.randomUUID() + extension;
        Path targetPath = trackImageDirectory.resolve(storedFileName);

        try {
            Files.createDirectories(trackImageDirectory);
            try (InputStream inputStream = imageFile.getInputStream()) {
                Files.copy(inputStream, targetPath, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException e) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED, e);
        }

        return new TrackImageResponse(
                trackImagePublicBaseUrl + trackImagePathPrefix + "/" + storedFileName
        );
    }

    // base64 data URI → 디스크 저장 → 공개 URL 반환.
    // 에디터 저장 흐름에서 호출 (multipart 가 아닌 JSON body 안에 썸네일을 같이 받기 위함).
    public String storeFromBase64(String dataUri) {
        if (dataUri == null || dataUri.isBlank()) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "썸네일이 비어 있습니다.");
        }

        // prefix로 mine/확장자 + 파일 이름 본문 분기
        String extension;
        String base64Payload;
        if (dataUri.startsWith(DATA_URI_PNG_PREFIX)) {
            extension = ".png";
            base64Payload = dataUri.substring(DATA_URI_PNG_PREFIX.length());
        } else if (dataUri.startsWith(DATA_URI_JPEG_PREFIX)) {
            extension = ".jpg";
            base64Payload = dataUri.substring(DATA_URI_JPEG_PREFIX.length());
        } else {
            throw new GeneralException(
                    ErrorStatus.INVALID_IMAGE_FILE,
                    "PNG 또는 JPEG data URI 만 허용합니다."
            );
        }

        if (base64Payload.isBlank()) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "썸네일 본문이 비어 있습니다.");
        }

        // base64 디코딩
        byte[] imageBytes;
        try {
            imageBytes = Base64.getDecoder().decode(base64Payload);
        } catch (IllegalArgumentException e) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "base64 디코딩에 실패했습니다.");
        }

        // UUID 파일명으로 디스크에 저장
        String storedFileName = UUID.randomUUID() + extension;
        Path targetPath = trackImageDirectory.resolve(storedFileName);

        try {
            Files.createDirectories(trackImageDirectory);
            Files.write(targetPath, imageBytes);
        } catch (IOException e) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED, e);
        }

        // URL 조립 및 응답
        return trackImagePublicBaseUrl + trackImagePathPrefix + "/" + storedFileName;
    }

    // 보상용 — 저장된 트랙 이미지를 공개 URL 기준으로 디스크에서 삭제.
    // 에디터 저장 흐름에서 DB 트랜잭션이 실패했을 때 디스크에 남은 고아 파일을 정리.
    // 보상 실패는 원인 예외(=호출자가 throw 할 진짜 예외)를 가리지 않도록 로그만 남긴다.
    public void deleteByUrl(String trackImageUrl) {
        if (trackImageUrl == null || trackImageUrl.isBlank()) {
            return;
        }

        String fileName = extractStoredFileName(trackImageUrl);
        if (fileName == null) {
            log.warn("track image cleanup skipped — invalid url: {}", trackImageUrl);
            return;
        }

        Path targetPath = trackImageDirectory.resolve(fileName);
        try {
            Files.deleteIfExists(targetPath);
        } catch (IOException e) {
            log.warn("track image cleanup failed: {}", targetPath, e);
        }
    }

    // 공개 URL 의 마지막 path 세그먼트만 파일명으로 사용.
    // path traversal 방지 — 슬래시/백슬래시/".." 포함 시 거부.
    private String extractStoredFileName(String trackImageUrl) {
        int slashIndex = trackImageUrl.lastIndexOf('/');
        if (slashIndex < 0 || slashIndex == trackImageUrl.length() - 1) {
            return null;
        }

        String fileName = trackImageUrl.substring(slashIndex + 1);
        if (fileName.contains("..") || fileName.contains("/") || fileName.contains("\\")) {
            return null;
        }
        return fileName;
    }

    //파일 검증 로직(빈 파일인지, 허용된 타입 체크)
    private void validateImageFile(MultipartFile imageFile) {
        if (imageFile == null || imageFile.isEmpty()) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "이미지 파일이 비어 있습니다.");
        }

        if (!ALLOWED_CONTENT_TYPES.contains(imageFile.getContentType())) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE,
                    "PNG 또는 JPEG 이미지만 업로드할 수 있습니다.");
        }

        extractExtension(imageFile.getOriginalFilename());
    }

    //확장자 추출 및 검증 로직
    private String extractExtension(String originalFilename) {
        if (originalFilename == null || originalFilename.isBlank()) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "파일 이름이 유효하지 않습니다.");
        }

        int extensionStartIndex = originalFilename.lastIndexOf('.');
        if (extensionStartIndex < 0 || extensionStartIndex == originalFilename.length() - 1) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "파일 확장자가 없습니다.");
        }

        String extension = originalFilename.substring(extensionStartIndex).toLowerCase();
        if (!ALLOWED_EXTENSIONS.contains(extension)) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "PNG 또는 JPEG 확장자만 허용합니다.");
        }

        return extension;
    }

    private String normalizePathPrefix(String pathPrefix) {
        if (pathPrefix == null || pathPrefix.isBlank()) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED,
                    "트랙 이미지 path prefix 설정이 비어 있습니다.");
        }

        String normalized = pathPrefix.trim();

        if (!normalized.startsWith("/")) {
            normalized = "/" + normalized;
        }

        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }

    private String normalizeBaseUrl(String baseUrl) {
        if (baseUrl == null || baseUrl.isBlank()) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED,
                    "트랙 이미지 public base url 설정이 비어 있습니다.");
        }

        String normalized = baseUrl.trim();

        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }
}
