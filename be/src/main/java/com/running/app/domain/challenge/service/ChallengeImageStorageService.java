package com.running.app.domain.challenge.service;

import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Base64;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class ChallengeImageStorageService {


    private final String CHALLENGE_IMAGE_DIR;
    private final String IMAGE_BASE_URL;
    private final String IMAGE_PREFIX;
    private final String CHALLENGE_DIR_PREFIX;

    public ChallengeImageStorageService(
            @Value("${app.upload.challenge-image-dir}") String challengeImageDir,
            @Value("${app.upload.track-image-public-base-url}") String imageBaseUrl,
            @Value("${app.upload.challenge-image-path-prefix}") String challengeDirPrefix
    ) {

        this.CHALLENGE_IMAGE_DIR = challengeImageDir;
        this.IMAGE_BASE_URL = imageBaseUrl;
        this.IMAGE_PREFIX = ".png"; // png 고정
        this.CHALLENGE_DIR_PREFIX = challengeDirPrefix;
    }


    // base64 data URI → 디스크 저장 → 공개 URL 반환.
    // 에디터 저장 흐름에서 호출 (multipart 가 아닌 JSON body 안에 썸네일을 같이 받기 위함).
    public String storeChallengeImage(String base64Image) {

        // 사진이 비어있는 경우(요청 실패 등), 확장자 안맞는 경우(AI 모델의 프롬프트 미준수 등)의 예외 처리 필요

        // 이미지 파일 디코딩
        byte[] imageBytes = Base64.getDecoder().decode(base64Image);

        // 이미지 저장 경로 생성
        String uuid = UUID.randomUUID().toString();
        Path dir = Paths.get(CHALLENGE_IMAGE_DIR);

        Path filePath = dir.resolve(uuid + IMAGE_PREFIX);

        // 이미지 저장 실행
        try {
            Files.createDirectories(dir);
            Files.write(filePath, imageBytes);
        } catch (IOException e) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED, e);
        }

        // db에 저장할 url 조합하여 응답
        return IMAGE_BASE_URL + CHALLENGE_DIR_PREFIX + "/" + uuid + IMAGE_PREFIX;
    }

    // 저장된 이미지 URL → 디스크에서 읽어 base64 반환
    public String readAsBase64(String imageUrl) {
        String filename = imageUrl.substring(imageUrl.lastIndexOf('/') + 1);
        Path filePath = Paths.get(CHALLENGE_IMAGE_DIR).resolve(filename);
        try {
            byte[] bytes = Files.readAllBytes(filePath);
            return Base64.getEncoder().encodeToString(bytes);
        } catch (IOException e) {
            throw new GeneralException(ErrorStatus.FILE_UPLOAD_FAILED, e);
        }
    }
}


