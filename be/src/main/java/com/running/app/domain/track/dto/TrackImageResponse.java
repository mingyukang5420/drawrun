package com.running.app.domain.track.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class TrackImageResponse {
    // 업로드 결과 경로를 담는 DTO

    //업로드 후 생성된 UUID 포함된 공개 경로
    private String trackImageUrl;
}
