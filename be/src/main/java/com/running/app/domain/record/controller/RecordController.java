package com.running.app.domain.record.controller;

import com.running.app.domain.record.dto.RecordRequest;
import com.running.app.domain.record.dto.RecordResponse;
import com.running.app.domain.record.service.RecordService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Record", description = "기록 관련 API")
@RestController
@RequiredArgsConstructor
@RequestMapping("/v1")
public class RecordController {

    private final RecordService recordService;

    @Operation(
            summary = "러닝 기록 전체 조회",
            description = """
                    로그인 사용자의 러닝 기록 목록을 최신순으로 조회
                    
                    무한스크롤을 위한 page, size, hasNext 값 전달받음
                    
                    기록 카드에 필요한 요약 정보 반환
                    """
    )
    @GetMapping("/record")
    public ApiResponse<RecordResponse.ListResultDTO> getRecordList(
            @AuthenticationPrincipal String loginId,
            @RequestParam(name = "page", defaultValue = "0") Integer page,
            @RequestParam(name = "size", defaultValue = "10") Integer size
    ) {

        RecordResponse.ListResultDTO response = recordService.getRecordList(
                loginId,
                page,
                size
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(
            summary = "러닝 활동 통계 조회",
            description = """
                    사용자의 러닝 활동 통계 조회
                    period 값에 따라 조회 범위와 차트 단위 변경
                    
                    period 옵션:
                    - week : 이번 주 통계, 요일별 차트
                    - month : 이번 달 통계, 일자별 차트
                    - year : 올해 통계, 월별 차트
                    - all : 전체 통계, 연도별 차트
                    - 기본값 : all  
                    """
    )
    @GetMapping("/record/stats")
    public ApiResponse<RecordResponse.StatsDTO> getRecordStats(
            @AuthenticationPrincipal String loginId,
            @RequestParam(name = "period", defaultValue = "all") String period
    ) {

        RecordResponse.StatsDTO response = recordService.getRecordStats(
                loginId,
                period
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(
            summary = "러닝 기록 상세 조회",
            description = """
                    로그인 사용자의 특정 러닝 기록 상세정보 조회
                    데이터 및 경로 좌표 nodes 배열로 변환해서 반환
                    """
    )
    @GetMapping("/record/{recordId}")
    public ApiResponse<RecordResponse.DetailDTO> getRecordDetail(
            @AuthenticationPrincipal String loginId,
            @PathVariable(name = "recordId") Long recordId
    ) {

        RecordResponse.DetailDTO response = recordService.getRecordDetail(
                loginId, recordId
        );

        return ApiResponse.onSuccess(response);
    }

    @Operation(
            summary = "러닝 기록 제목 수정",
            description = """
                    로그인 사용자의 러닝 기록 제목 수정.
                    """
    )
    @PatchMapping("/record/{recordId}")
    public ApiResponse<Void> changeRecordTitle(
            @AuthenticationPrincipal String loginId,
            @PathVariable(name = "recordId") Long recordId,
            @Valid @RequestBody RecordRequest.ChangeTitleDTO request
    ) {

        recordService.changeRecordTitle(
                loginId,
                recordId,
                request
        );

        return ApiResponse.OK;
    }


}
