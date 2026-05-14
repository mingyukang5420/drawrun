package com.running.app.domain.ranking.controller;

import com.running.app.domain.ranking.dto.RankingResponse.RecordRankingResponse;
import com.running.app.domain.ranking.service.RankingService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Ranking", description = "랭킹 조회 API")
@RestController
@RequiredArgsConstructor
@Slf4j
@RequestMapping("/v1/course")
public class RankingController {

    private final RankingService rankingService;

    @GetMapping("/{courseId}/ranking/record")
    public ApiResponse<RecordRankingResponse> getRecordRanking(

            @AuthenticationPrincipal String loginId,
            @PathVariable long courseId
    ) {
        RecordRankingResponse recordRanking = rankingService.getRecordRanking(loginId, courseId);
        return ApiResponse.onSuccess(recordRanking);
    }
}
