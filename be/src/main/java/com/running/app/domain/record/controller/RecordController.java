package com.running.app.domain.record.controller;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.service.RecordService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Record", description = "러닝 기록 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/run/end")
public class RecordController {

    private final RecordService recordService;

    @Operation(
            summary = "러닝 기록 생성",
            description = """
                    러닝 종료 후 FE에서 전달한 좌표 노드, 거리, 트랙 이미지 URL, 러닝 데이터를 기반으로 러닝 기록을 생성합니다.

                    처리 순서:
                    1. nodes를 MultiLineString으로 변환
                    2. tracks 테이블에 경로 저장
                    3. records 테이블에 러닝 기록 저장

                    현재는 distance, avgPace, calories, cadence, trackImageUrl 값을 FE에서 계산/생성하여 전달받습니다.
                    """
    )
    @PostMapping
    public ApiResponse<RecordResponse.CreateResultDTO> createRecord(
            @RequestBody RecordRequest.CreateDTO request
    ) {
        //회원관련 없어서 임시로 1L로 처리
        Long memberId = 1L;

        RecordResponse.CreateResultDTO response = recordService.createRecord(
                memberId,
                request
        );

        return ApiResponse.onSuccess(response);
    }

}
