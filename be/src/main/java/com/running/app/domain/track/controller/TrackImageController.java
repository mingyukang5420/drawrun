package com.running.app.domain.track.controller;

import com.running.app.domain.track.dto.TrackImageResponse;
import com.running.app.domain.track.service.TrackImageStorageService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "Track", description = "트랙 이미지 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/tracks")
public class TrackImageController {
    // 업로드 API

    private final TrackImageStorageService trackImageStorageService;

    @Operation(
            summary = "트랙 이미지 업로드",
            description = """
                          트랙 스냅샷 이미지를 업로드
                          이후 Track.trackImageUrl 에 저장할 경로를 반환
                          """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "이미지 업로드 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "유효하지 않은 이미지 파일",
                    content = @Content(schema = @Schema(implementation = ApiResponse.class))
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "500",
                    description = "이미지 업로드 실패",
                    content = @Content(schema = @Schema(implementation = ApiResponse.class))
            )
    })
    //최종 엔드포인트 -> /v1/trakcs/image
    //multipart/form-data 요청만 받음
    @PostMapping(
            value = "/image",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ApiResponse<TrackImageResponse> uploadTrackImage(
            // 프론트에서 "image"라는 키 이름으로 파일 보내야함
            @RequestPart("image") MultipartFile image
    ) {
        TrackImageResponse response = trackImageStorageService.store(image);
        return ApiResponse.onSuccess(response);
    }
}
