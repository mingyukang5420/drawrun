package com.running.app.domain.editor.dto;

import java.util.ArrayList;
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

        @Builder.Default
        private List<WayInnerResponse> ways = new ArrayList<>();
    }

    @Getter
    @Builder
    @NoArgsConstructor(access = AccessLevel.PROTECTED)
    @AllArgsConstructor(access = AccessLevel.PRIVATE)
    public static class WayInnerResponse {

        // 도로 Id
        private Long id;
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
        @Builder.Default
        private List<Double[]> coordinates = new ArrayList<>();
    }
}
