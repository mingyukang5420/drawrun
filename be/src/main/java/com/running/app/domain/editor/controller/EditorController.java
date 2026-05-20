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
                    1. 썸네일(base64) 을 디스크에 저장하고 공개 URL 확보 (트랜잭션 밖)
                    2. 좌표가 도보 가능한 길(osm_ways_split) buffer 내에 있는지 검증 (실패 시 400 INVALID_ROUTE)
                    3. Track 생성 (거리는 PostGIS ST_Length 로 자동 계산, trackImageUrl = 1단계에서 받은 URL)
                    4. challengeId 로 Challenge 조회 (없으면 404 CHALLENGE_NOT_FOUND) → CourseDraft 와 연결
                    5. CourseDraft 생성 (검증런 전이므로 status=READY, 위 Challenge 참조 포함)
                    6. 2~5 단계 중 어느 하나라도 실패하면 1단계에서 만든 디스크 파일을 보상 삭제
                    
                    thumbnailBase64 형식:
                    - "data:image/png;base64,...." 또는 "data:image/jpeg;base64,...." (data URI 형식)
                    - 다른 mime 또는 prefix 누락 시 400 INVALID_IMAGE_FILE
                    
                    challengeId:
                    - 이 드래프트가 어떤 챌린지에 속하는지 식별 (해당 챌린지의 후보 코스로 등록)
                    """,
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    description = "에디터 저장 요청 바디 — 제목, 사용자가 그린 좌표 시퀀스(order 기준 정렬), 썸네일 base64, 연결할 challengeId",
                    content = @Content(
                            mediaType = "application/json",
                            examples = @ExampleObject(
                                    name = "에디터 저장 요청 예시",
                                    value = """
                                            {
                                              "title": "한강 러닝 코스",
                                              "coordinates": [
                                                { "lat": 37.5480598, "lng": 126.9177061, "order": 1 },
                                                { "lat": 37.5479675, "lng": 126.9181941, "order": 2 },
                                                { "lat": 37.54793, "lng": 126.91838, "order": 3 }
                                            
                                              ],
                                              "thumbnailBase64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==",
                                              "challengeId": 1
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
                    description = """
                            검증 실패. 사유 코드:
                            - INVALID_ROUTE : 뛸 수 없는 길 포함
                            - INVALID_IMAGE_FILE : thumbnailBase64 가 PNG/JPEG data URI 가 아님 / base64 디코딩 실패 / 본문 빔
                            - INVALID_TRACK_IMAGE_URL : 저장된 이미지 URL 형식 이상 (서버 설정 불일치 등)
                            - 입력 형식 오류 (title 길이/좌표 개수/order 누락/thumbnailBase64 누락 등)
                            """
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "401",
                    description = "인증 실패 — 토큰 없음/만료/위변조"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "404",
                    description = "대상 없음 — 사용자(MEMBER_NOT_FOUND) 또는 챌린지(CHALLENGE_NOT_FOUND)"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "500",
                    description = "썸네일 디스크 쓰기 실패 — FILE_UPLOAD_FAILED"
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
            summary = "에디터 수정 — 드래프트 제목/경로 부분 갱신",
            description = """
                    반드시 도보 가능한 좌표를 확인한 후 해당 좌표를 요청 body에 넣어야 작동함
                    
                    READY 상태의 본인 드래프트를 수정.
                    
                    요청 contract (FE/BE 협의 결과):
                    - title / coordinates 는 변경 여부와 무관하게 매 요청에 현재 값 그대로 포함해서 전송
                    - thumbnailBase64 는 좌표가 바뀐 경우에만 포함 (data:image/png;base64,... 또는 data:image/jpeg;base64,...)
                    - 좌표가 바뀌지 않은 PATCH 면 썸네일은 생략(null) 또는 빈 문자열
                    
                    처리 흐름:
                    1. 권한/상태 검증 + 좌표 변경 여부 판정 (read-only)
                    2. 좌표가 바뀐 경우에만 새 썸네일을 디스크에 저장
                    3. DB 트랜잭션 안에서 좌표 비교 재확인 후
                       - 좌표 변경: OSM 검증 → 새 Track INSERT → swap → 난이도 재산정 → 옛 Track 삭제
                       - 제목 변경: title UPDATE
                    4. 커밋 성공 후 옛 썸네일 디스크 삭제
                    
                    수정 가능 조건:
                    - 본인 소유 드래프트 (타인 → 403 FORBIDDEN)
                    - status = READY (DONE → 400 EDITOR_NOT_EDITABLE)
                    """,
            requestBody = @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    required = true,
                    description = "에디터 수정 요청 바디 — 제목/좌표는 매 요청 풀바디 동봉, 썸네일은 좌표 변경 시에만 동봉",
                    content = @Content(
                            mediaType = "application/json",
                            examples = {
                                    @ExampleObject(
                                            name = "좌표 변경 — 썸네일 포함",
                                            value = """
                                                    {
                                                      "title": "한강 러닝 코스 수정함",
                                                      "coordinates": [
                                                        { "lat": 37.5480598, "lng": 126.9177061, "order": 1 },
                                                        { "lat": 37.5479675, "lng": 126.9181941, "order": 2 },
                                                        { "lat": 37.5475100, "lng": 126.9190000, "order": 3 }
                                                      ],
                                                      "thumbnailBase64": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
                                                    }
                                                    """
                                    ),
                                    @ExampleObject(
                                            name = "좌표 미변경 — 제목만 수정 (썸네일 생략)",
                                            value = """
                                                    {
                                                      "title": "한강 러닝 코스 — 제목만 수정",
                                                      "coordinates": [
                                                        { "lat": 37.5480598, "lng": 126.9177061, "order": 1 },
                                                        { "lat": 37.5479675, "lng": 126.9181941, "order": 2 },
                                                        { "lat": 37.54793, "lng": 126.91838, "order": 3 }
                                                      ],
                                                      "thumbnailBase64": null
                                                    }
                                                    """
                                    )
                            }
                    )
            )
    )
    @ApiResponses({
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "200",
                    description = "수정 성공 — 갱신된 드래프트 상세 응답"
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "400",
                    description = """
                            검증 실패. 사유 코드:
                            - INVALID_ROUTE : 좌표가 도보 가능한 길 위에 있지 않음
                            - INVALID_IMAGE_FILE : 좌표 변경 시 썸네일 누락 / 형식 오류 / base64 디코딩 실패
                            - INVALID_TRACK_IMAGE_URL : 저장된 이미지 URL 형식 이상
                            - EDITOR_NOT_EDITABLE : 드래프트가 READY 상태가 아님
                            - 입력 형식 오류 (title 길이/좌표 개수/order 누락 등)
                            """
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
            ),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(
                    responseCode = "500",
                    description = "썸네일 디스크 쓰기 실패 — FILE_UPLOAD_FAILED"
            )
    })
    public ApiResponse<DraftDetailResponse> update(
            @AuthenticationPrincipal String loginId,

            @Parameter(description = "수정할 드래프트 ID. 본인이 만든 READY 상태 드래프트만 수정 가능", required = true, example = "42")
            @PathVariable Long courseDraftId,

            @Valid @RequestBody EditorRequest.UpdateRequest request
    ) {
        DraftDetailResponse response = editorService.update(loginId, courseDraftId, request);

        return ApiResponse.onSuccess(response);
    }

    @DeleteMapping("/{courseDraftId}")
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
            @PathVariable Long courseDraftId
    ) {

        editorService.delete(loginId, courseDraftId);

        return ApiResponse.OK;
    }

    @Operation(
            summary = "최근 챌린지 두개에 맞는 courseDraft 목록 조회",
            description = """
                    page는 기본값 0, similarityScore는 기록이 없을 경우 응답에 포함되지 않습니다.

                    각 드래프트 응답에는 challengeId 가 함께 포함되어, FE 가 코스 카드에서 러닝 시작 시
                    종료 API 본문까지 챌린지 컨텍스트를 그대로 전달할 수 있습니다.
                    챌린지에 묶이지 않은 일반 드래프트는 challengeId 가 null 이며 응답에서 생략됩니다.
                    """
    )
    @GetMapping("/challenge")
    public ApiResponse<DraftListResultResponse> getCourseDraftList(
            @AuthenticationPrincipal String loginId,
            @RequestParam(defaultValue = "0") Integer page
    ) {

        DraftListResultResponse response = editorService.getCourseDraftList(loginId, page);

        return ApiResponse.onSuccess(response);
    }

    @Operation(
            summary = "특정 challengeId에 맞는 courseDraft 상세 조회"
    )
    @GetMapping("/{courseDraftId}/challenge/{challengeId}")
    public ApiResponse<DraftDetailResponse> getCourseDraftDetail(
            @PathVariable Long courseDraftId,
            @PathVariable Long challengeId,
            @AuthenticationPrincipal String loginId
    ) {

        DraftDetailResponse response = editorService.getCourseDraftDetail(courseDraftId,
                challengeId, loginId);

        return ApiResponse.onSuccess(response);
    }
}
