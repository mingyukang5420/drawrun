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
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

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

    private final Path trackImageDirectory;
    private final String trackImageUrlPrefix;

    public TrackImageStorageService(
            @Value("${app.upload.track-image-dir}") String trackImageDir,
            @Value("${app.upload.track-image-url-prefix}") String trackImageUrlPrefix
    ) {
        this.trackImageDirectory = Paths.get(trackImageDir).toAbsolutePath().normalize();
        this.trackImageUrlPrefix = normalizeUrlPrefix(trackImageUrlPrefix);
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

        // ./uploads/tracks/{UUID}.png 의 형태 접근 경로 프론트에 반환
        return new TrackImageResponse(trackImageUrlPrefix + "/" + storedFileName);
    }

    //파일 검증 로직(빈 파일인지, 허용된 타입 체크)
    private void validateImageFile(MultipartFile imageFile) {
        if (imageFile == null || imageFile.isEmpty()) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "이미지 파일이 비어 있습니다.");
        }

        if (!ALLOWED_CONTENT_TYPES.contains(imageFile.getContentType())) {
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "PNG 또는 JPEG 이미지만 업로드할 수 있습니다.");
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
            throw new GeneralException(ErrorStatus.INVALID_IMAGE_FILE, "PNG 또는 JPEG 확장자만 허용됩니다.");
        }

        return extension;
    }

    // prefix 정리 해 형태 맞추는 메서드
    private String normalizeUrlPrefix(String urlPrefix) {
        if (urlPrefix == null || urlPrefix.isBlank()) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED, "트랙 이미지 URL prefix 설정이 비어 있습니다.");
        }

        String normalized = urlPrefix.trim();
        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        if (!normalized.startsWith("/")) {
            normalized = "/" + normalized;
        }

        return normalized;
    }
}
