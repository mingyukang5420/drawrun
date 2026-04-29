package com.running.app.domain.editor.controller;

import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.global.response.ApiResponse;
import com.running.app.global.response.osm.entity.OsmWay;
import com.running.app.global.response.osm.service.OsmService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/v1/editor")
@RequiredArgsConstructor
@Tag(name = "코스 에디터")
public class EditorController {

    private final OsmService osmService;

    @GetMapping("/way")
    @Operation(
            summary = "현재 위치 반경에서 도보 가능한 길 조회",
            description = "지도 viewport 영역 내 보행 가능한 도로(좌표)를 조회합니다. zoom 레벨은 테스트 필요(16 이상 권장)"
    )
    public ApiResponse<WayResponse> workableWay(
            @Parameter(description = "바운딩박스 최소 위도 (남쪽 경계). 예: 37.5449", required = true, example = "37.5449")
            @RequestParam Double minLat,

            @Parameter(description = "바운딩박스 최소 경도 (서쪽 경계). 예: 126.9168", required = true, example = "126.9168")
            @RequestParam Double minLng,

            @Parameter(description = "바운딩박스 최대 위도 (북쪽 경계). 예: 37.5631", required = true, example = "37.5631")
            @RequestParam Double maxLat,

            @Parameter(description = "바운딩박스 최대 경도 (동쪽 경계). 예: 126.9252", required = true, example = "126.9252")
            @RequestParam Double maxLng,

            @Parameter(description = "현재 지도 줌 레벨. 16 미만이면 빈 배열 반환. 네이버 지도 기준 16~21 권장", required = true, example = "16")
            @RequestParam Integer zoom
    ) {

        List<OsmWay> walkableWays = osmService.getWalkableWays(minLat, minLng, maxLat, maxLng,
                zoom);

        WayResponse wayResponse = EditorConverter.toWayResponse(walkableWays);

        return ApiResponse.onSuccess(wayResponse);
    }
}
