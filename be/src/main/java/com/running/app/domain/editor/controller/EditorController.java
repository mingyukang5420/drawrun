package com.running.app.domain.editor.controller;

import com.running.app.domain.editor.converter.EditorConvertor;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.global.response.ApiResponse;
import com.running.app.global.response.osm.entity.OsmWay;
import com.running.app.global.response.osm.service.OsmService;
import jakarta.validation.constraints.NotNull;
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
public class EditorController {

    private final OsmService osmService;

    @GetMapping("/way")
    public ApiResponse<WayResponse> workableWay(
            @RequestParam @NotNull Double minLat,
            @RequestParam @NotNull Double minLng,
            @RequestParam @NotNull Double maxLat,
            @RequestParam @NotNull Double maxLng,
            @RequestParam @NotNull Integer zoom
    ) {

        List<OsmWay> walkableWays = osmService.getWalkableWays(minLat, minLng, maxLat, maxLng,
                zoom);
        log.info("얼마나 많은거야 미친, {}", walkableWays.size());
        WayResponse wayResponse = EditorConvertor.toWayResponse(walkableWays);

        return ApiResponse.onSuccess(wayResponse);
    }
}
