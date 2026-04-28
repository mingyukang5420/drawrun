package com.running.app.domain.editor.controller;

import com.running.app.domain.editor.converter.EditorConvertor;
import com.running.app.domain.editor.dto.EditorRequest.WayRequest;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.global.response.ApiResponse;
import com.running.app.global.response.osm.entity.OsmWay;
import com.running.app.global.response.osm.service.OsmService;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping("/v1/editor")
@RequiredArgsConstructor
public class EditorController {

    private final OsmService osmService;

    @GetMapping("/way")
    public ApiResponse<WayResponse> workableWay(
            @Valid @ModelAttribute WayRequest request
    ) {
        
        List<OsmWay> walkableWays = osmService.getWalkableWays(request);
        WayResponse wayResponse = EditorConvertor.toWayResponse(walkableWays);

        return ApiResponse.onSuccess(wayResponse);
    }
}
