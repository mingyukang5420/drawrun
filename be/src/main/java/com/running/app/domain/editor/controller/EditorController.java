package com.running.app.domain.editor.controller;

import com.running.app.domain.coursedraft.type.CourseDraftFilterType;
import com.running.app.domain.editor.converter.EditorConverter;
import com.running.app.domain.editor.dto.EditorRequest;
import com.running.app.domain.editor.dto.EditorResponse.DraftDetailResponse;
import com.running.app.domain.editor.dto.EditorResponse.DraftListResultResponse;
import com.running.app.domain.editor.dto.EditorResponse.SaveResponse;
import com.running.app.domain.editor.dto.EditorResponse.WayResponse;
import com.running.app.domain.editor.service.EditorService;
import com.running.app.global.osm.entity.OsmSplit;
import com.running.app.global.osm.service.OsmService;
import com.running.app.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
    private final EditorService editorService;

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

        List<OsmSplit> walkableWays = osmService.getWalkableWays(minLat, minLng, maxLat, maxLng,
                zoom);

        WayResponse wayResponse = EditorConverter.toWayResponse(walkableWays);

        return ApiResponse.onSuccess(wayResponse);
    }

    @GetMapping
    @Operation(
            summary = "에디터 목록 조회 — 사용자 드래프트 목록",
            description = """
                    로그인 사용자가 에디터에서 저장한 드래프트(course_drafts) 목록을 filter 기준으로 조회.

                    filter:
                    - ALL        : 전체 (상태·등록 여부 무관)
                    - READY      : 작성중 (에디터 저장만, 아직 뛰지 않음 → status=READY)
                    - DONE       : 검증됨 (뛰어봤으나 아직 정식 등록 전 → status=DONE && 미등록)
                    - REGISTERED : 등록됨 (해당 드래프트로 뛴 record 가 정식 코스로 등록됨)
                    DONE 과 REGISTERED 는 disjoint.

                    페이지네이션: page (0-based), size 10 고정. created_at DESC 정렬.
                    응답: { content, page, size, hasNext }
                    """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "조회 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = "사용자 없음 — MEMBER_NOT_FOUND"
            )
    })
    public ApiResponse<DraftListResultResponse> getDraftList(
            @AuthenticationPrincipal String loginId,

            @Parameter(description = "필터 — ALL / READY / DONE / REGISTERED", required = true, example = "ALL")
            @RequestParam CourseDraftFilterType filter,

            @Parameter(description = "페이지 번호(0-based). 기본값 0", example = "0")
            @RequestParam(defaultValue = "0") Integer page
    ) {
        DraftListResultResponse response = editorService.getDraftList(loginId, filter, page);

        return ApiResponse.onSuccess(response);
    }

    @GetMapping("/{courseDraftId}")
    @Operation(
            summary = "에디터 상세 조회 — 본인 드래프트 상세",
            description = """
                    본인이 만든 특정 드래프트의 상세 정보를 조회.

                    응답 status:
                    - READY      : 작성중 (아직 뛰지 않음)
                    - DONE       : 검증됨 (뛰어봤으나 정식 등록 전)
                    - REGISTERED : 등록됨 (이 드래프트 기반 record 가 정식 코스로 등록됨)
                      → 백엔드 내부에서는 draft.status(READY/DONE) + courses 매핑 여부의 derived 값.

                    coordinates: 경로 좌표 시퀀스 [{lat, lng}, ...]

                    권한: 본인 소유 드래프트만 조회 가능. 타인 드래프트면 403 FORBIDDEN.
                    """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "조회 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "403",
                    description = "권한 없음 — 본인이 만든 드래프트가 아님(FORBIDDEN)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = "대상 없음 — 사용자(MEMBER_NOT_FOUND) 또는 드래프트(COURSE_NOT_FOUND)"
            )
    })
    public ApiResponse<DraftDetailResponse> getDraftDetail(
            @AuthenticationPrincipal String loginId,

            @Parameter(description = "조회할 드래프트 ID", required = true, example = "1")
            @PathVariable Long courseDraftId
    ) {
        DraftDetailResponse response = editorService.getDraftDetail(loginId, courseDraftId);

        return ApiResponse.onSuccess(response);
    }

    @PostMapping
    @Operation(
            summary = "에디터 저장 — 사용자 커스텀 코스 등록",
            description = """
                    사용자가 에디터에서 그린 커스텀 러닝 코스를 저장.

                    처리 흐름:
                    1. 좌표가 도보 가능한 길(osm_ways_split) buffer 내에 있는지 검증 (실패 시 400 INVALID_ROUTE)
                    2. Track 생성 (거리는 PostGIS ST_Length 로 자동 계산)
                    3. Course 생성 (검증런 전이므로 status=READY, completionScore=0)
                    """,
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    description = "에디터 저장 요청 바디 — 제목과 사용자가 그린 좌표 시퀀스(order 기준 정렬)",
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(
                                    name = "에디터 저장 요청 예시",
                                    value = """
                                            {
                                              "title": "한강 러닝 코스",
                                              "coordinates": [
                                                { "lat": 37.5500, "lng": 126.9200, "order": 1 },
                                                { "lat": 37.5510, "lng": 126.9210, "order": 2 },
                                                { "lat": 37.5520, "lng": 126.9220, "order": 3 }
                                              ]
                                            }
                                            """
                            )
                    )
            )
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "저장 성공 — status=READY, isValidRoute=true 응답"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "검증 실패 — 뛸 수 없는 길 포함(INVALID_ROUTE) 또는 입력 형식 오류(title 길이/좌표 개수/order 누락 등)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            )
    })
    public ApiResponse<SaveResponse> save(
            @AuthenticationPrincipal String loginId,
            @Valid @RequestBody EditorRequest.SaveRequest request
    ) {
        SaveResponse response = editorService.save(loginId, request);

        return ApiResponse.onSuccess(response);
    }

    @PatchMapping("/{courseDraftId}")
    @Operation(
            summary = "에디터 수정 — 제목 + 좌표 시퀀스 갱신",
            description = """
                    본인이 만든 READY 상태 드래프트의 제목과 좌표를 갱신.

                    수정 가능 조건:
                    - 본인 소유 드래프트
                    - status == READY (DONE / 등록된 상태는 수정 불가)

                    요청 본문은 저장(POST /v1/editor) 과 동일 형식 — title + coordinates(lat, lng, order).
                    수정 사항이 없는 항목도 원래 값을 그대로 담아 보낸다.

                    처리 흐름:
                    1. 본인 소유 / READY 상태 검증
                    2. 좌표가 osm_ways_split 위에 있는지 검증 (실패 시 INVALID_ROUTE)
                    3. 새 Track INSERT (PostGIS ST_Length 로 distance 자동 계산)
                    4. CourseDraft 의 title / track / difficulty 갱신 (distance 변경 → difficulty 자동 재산정)
                    5. 기존 Track 미참조 시 동반 삭제

                    응답: 상세 조회와 동일 (`courseDraftId / title / status / coordinates`)
                    """,
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    description = "에디터 수정 요청 바디 — 제목과 좌표 시퀀스(order 기준 정렬). 수정 없는 항목도 원래 값 그대로 포함.",
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(
                                    name = "에디터 수정 요청 예시",
                                    value = """
                                            {
                                              "title": "한강 러닝 코스",
                                              "coordinates": [
                                                { "lat": 37.5480598, "lng": 126.9177061, "order": 1 },
                                                { "lat": 37.5479675, "lng": 126.9181941, "order": 2 },
                                                { "lat": 37.54793, "lng": 126.91838, "order": 3 }
                                              ]
                                            }
                                            """
                            )
                    )
            )
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "수정 성공"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "검증 실패 — 입력 형식 오류 / 뛸 수 없는 길(INVALID_ROUTE) / 수정 불가 상태(EDITOR_NOT_EDITABLE)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "403",
                    description = "권한 없음 — 본인이 만든 드래프트가 아님(FORBIDDEN)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = "대상 없음 — 사용자(MEMBER_NOT_FOUND) 또는 드래프트(COURSE_NOT_FOUND)"
            )
    })
    public ApiResponse<DraftDetailResponse> update(
            @AuthenticationPrincipal String loginId,

            @Parameter(description = "수정할 드래프트 ID", required = true, example = "1")
            @PathVariable Long courseDraftId,

            @Valid @RequestBody EditorRequest.SaveRequest request
    ) {
        DraftDetailResponse response = editorService.update(loginId, courseDraftId, request);

        return ApiResponse.onSuccess(response);
    }

    @DeleteMapping
    @Operation(
            summary = "에디터 삭제 — 미등록 임시 코스(드래프트) 삭제",
            description = """
                    사용자가 에디터에서 임시 저장한(아직 정식 코스로 등록되지 않은) 드래프트를 삭제.

                    삭제 대상:
                    - status = READY 인 CourseDraft (에디터 임시 저장본)
                    - DONE(= 정식 코스 등록 가능 후보) 상태는 삭제 불가 → 400 ALREADY_REGISTERED_COURSE

                    처리 흐름:
                    1. loginId 로 Member 조회 (없으면 404 MEMBER_NOT_FOUND)
                    2. courseDraftId 로 CourseDraft 조회 (없으면 404 COURSE_NOT_FOUND)
                    3. 본인 소유 검증 (다른 사용자의 드래프트면 403 FORBIDDEN)
                    4. 상태 검증 (status == DONE 이면 400 ALREADY_REGISTERED_COURSE)
                    5. CourseDraft 삭제
                    6. RunningRecord 가 참조하지 않는 Track 이면 동반 삭제 (참조 중이면 보존)
                    """
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "삭제 성공 — 응답 body 없음"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = "정식 코스 등록 가능 후보(DONE) 상태 — ALREADY_REGISTERED_COURSE"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "403",
                    description = "권한 없음 — 본인이 만든 드래프트가 아님(FORBIDDEN)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = "대상 없음 — 사용자(MEMBER_NOT_FOUND) 또는 드래프트(COURSE_NOT_FOUND)"
            )
    })
    public ApiResponse<Void> delete(
            @AuthenticationPrincipal String loginId,

            @Parameter(description = "삭제할 임시 코스(드래프트) ID. 본인이 만든 READY 상태 드래프트만 삭제 가능", required = true, example = "42")
            @RequestParam Long courseDraftId
    ) {

        editorService.delete(loginId, courseDraftId);

        return ApiResponse.OK;
    }
}
