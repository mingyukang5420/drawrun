package com.running.app.domain.run.controller;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.service.RecordService;
import com.running.app.domain.run.dto.RunRequest;
import com.running.app.domain.run.dto.RunResponse;
import com.running.app.domain.run.service.RunService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;


@Tag(name = "Run", description = "러닝 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/run")
public class RunController {

    private final RunService runService;
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
                                              "trackImageUrl": "https://k14a103.p.ssafy.io/uploads/tracks/550e8400-e29b-41d4-a716-446655440000.png",
                                              "runningTime": 1800,
                                              "avgPace": 8.77,
                                              "calories": 240,
                                              "cadence": 162,
                                              "startedAt": "2026-04-29T12:30:00",
                                              "endedAt": "2026-04-29T13:00:00",
                                              "challengeId": null,
                                              "similarityScore": null,
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
    @PostMapping("/end")
    public ApiResponse<Void> createRecord(
            @AuthenticationPrincipal String loginId,
            @Valid @RequestBody RecordRequest.CreateDTO request

    ) {
        recordService.createRecord(
                loginId,
                request
        );

        return ApiResponse.OK;
    }

    @Operation(
            summary = "러닝 시작",
            description = """
                    사용자가 선택한 러닝 타입에 따라 시작 시 필요한 경로 좌표 반환
                    
                    - 자유 러닝: courseId = null, courseDraftId = null
                    - 공식 코스 러닝: courseId != null, courseDraftId = null
                    - 에디터 코스 러닝: courseId = null, courseDraftId != null
                    - courseId와 courseDraftId를 동시에 보내면 400 에러
                    """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "러닝 시작 성공",
                    content = @Content(
                            mediaType = "application/json",
                            examples = {
                                    @ExampleObject(
                                            name = "자유 러닝 응답",
                                            value = """
                                                    {
                                                      "isSuccess": true,
                                                      "code": "200",
                                                      "message": "성공입니다.",
                                                      "result": {
                                                        "nodes": null
                                                      }
                                                    }
                                                    """
                                    ),
                                    @ExampleObject(
                                            name = "코스 러닝 응답",
                                            value = """
                                                    {
                                                      "isSuccess": true,
                                                      "code": "200",
                                                      "message": "성공입니다.",
                                                      "result": {
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
                                                            "lat": 37.49430,
                                                            "lng": 127.04677
                                                          }
                                                        ]
                                                      }
                                                    }
                                                    """
                                    )
                            }
                    )
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "courseId와 courseDraftId를 동시에 전달한 잘못된 요청",
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(
                                    name = "잘못된 요청",
                                    value = """
                                            {
                                              "isSuccess": false,
                                              "code": "400",
                                              "message": "잘못된 요청입니다.",
                                              "result": null
                                            }
                                            """
                            )
                    )
            )
    })
    @GetMapping("/start")
    public ApiResponse<RunResponse.StartDTO> startRun(
            @RequestParam(required = false) Long courseId,
            @RequestParam(required = false) Long courseDraftId

    ) {
        RunRequest.StartDTO request = new RunRequest.StartDTO(courseId, courseDraftId);
        RunResponse.StartDTO response = runService.startRun(request);
        return ApiResponse.onSuccess(response);
    }
}
