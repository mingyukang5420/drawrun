package com.running.app.domain.run.controller;

import com.running.app.domain.run.dto.RunRequest;
import com.running.app.domain.run.dto.RunResponse;
import com.running.app.domain.run.service.RunService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;


@Tag(name = "Run", description = "러닝 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1/run")
public class RunController {

    private final RunService runService;

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
