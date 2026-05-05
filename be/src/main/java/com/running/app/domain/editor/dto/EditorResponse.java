package com.running.app.domain.editor.dto;

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

        private Long editorId;     // course_id
        private String title;
        private String status;     // READY / DONE
        private Boolean isValidRoute;
    }
}
