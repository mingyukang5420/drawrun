package com.running.app.domain.record.controller;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.service.RecordService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Record", description = "기록 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1")
public class RecordController {

    private final RecordService recordService;

    @Operation(
            summary = "러닝 기록 생성(러닝 종료)",
            description = """
                    러닝 종료 후 앱에서 전달해 주는 데이터를 기반으로 러닝 기록을 생성.

                    처리 순서:
                    1. nodes를 MultiLineString으로 변환
                    2. tracks 테이블에 경로 저장
                    3. records 테이블에 러닝 기록 저장
                    """,
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    description = "러닝 종료 후 기록 생성 요청 바디",
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(
                                    name = "러닝 기록 생성 요청 예시",
                                    value = """
                                            {
                                              "courseId": null,
                                              "title": "저녁 러닝",
                                              "distance": 3.42,
                                              "trackImageUrl": "https://example.com/tracks/sample-track.png",
                                              "runningTime": 1800,
                                              "avgPace": 8.77,
                                              "calories": 240,
                                              "cadence": 162,
                                              "startedAt": "2026-04-29T12:30:00",
                                              "endedAt": "2026-04-29T13:00:00",
                                              "nodes": [
                                                {
                                                  "lat": 37.50238,
                                                  "lng": 127.04306
                                                },
                                                {
                                                  "lat": 37.50264,
                                                  "lng": 127.04274
                                                },
                                                {
                                                  "lat": 37.4943,
                                                  "lng": 127.04677
                                                },
                                                {
                                                  "lat": 37.49899,
                                                  "lng": 127.06052
                                                },
                                                {
                                                  "lat": 37.50699,
                                                  "lng": 127.05664
                                                }
                                              ]
                                            }
                                            """
                            )
                    )
            )
    )
    @PostMapping("/run/end")
    public ApiResponse<Void> createRecord(@RequestBody RecordRequest.CreateDTO request) {

        //회원관련 없어서 임시로 1L로 처리
        Long memberId = 1L;

        recordService.createRecord(
                memberId,
                request
        );

        return ApiResponse.OK;
    }

}
