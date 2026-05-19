package com.running.app.domain.editor.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonInclude.Include;
import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

public abstract class EditorResponse {

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class WayResponse {

        private List<WayInnerResponse> ways;
    }

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class WayInnerResponse {

        // osm 도로 id
        private Long osmId;
        private String highway;
        private String name;

        private Geom geom;
    }

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class Geom {

        private String type;
        // 좌표 배열을 담을 리스트
        private List<Double[]> coordinates;
    }

    // 에디터 저장 응답
    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class SaveResponse {

        private Long courseDraftId;
        private String title;
        private String status;     // READY / DONE (내부 enum DRAFT/VERIFIED 와 매핑)
        private Boolean isValidRoute;
    }

    // 에디터 목록 조회 — 단일 항목
    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class DraftListResponse {

        private Long courseDraftId;
        private Long courseId;          // 미등록 시 null
        private String title;
        private String difficulty;
        private String status;          // READY / DONE
        private Double distance;        // 소수점 1째 자리 반올림 (예: 2.3)
        private String trackImageUrl;
        private String createdAt;       // YYYY-MM-DD

        @JsonInclude(Include.NON_NULL)
        private Double similarityScore;
    }

    // 에디터 목록 조회 — Slice 결과 wrapper
    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class DraftListResultResponse {

        private List<DraftListResponse> content;
        private Integer page;
        private Integer size;
        private Boolean hasNext;

        @JsonInclude(Include.NON_NULL)
        private String challengeTitle;
    }

    // 에디터 상세 조회 응답.
    // status 는 draft.status(READY/DONE) 와 등록 여부(REGISTERED) 가 합쳐진 derived 값.
    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class DraftDetailResponse {

        private Long courseDraftId;
        private String title;
        private String status;                            // READY / DONE / REGISTERED
        private List<TrackRequest.NodeDTO> coordinates;   // [{lat, lng}, ...]

        @JsonInclude(Include.NON_NULL)
        private String polygonImageUrl;
        @JsonInclude(Include.NON_NULL)
        private String challengeTitle;
    }
}
