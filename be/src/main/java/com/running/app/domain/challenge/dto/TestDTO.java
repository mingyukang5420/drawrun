package com.running.app.domain.challenge.dto;

import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class TestDTO {

    private String easy;
    private String hard;

    @Getter
    @NoArgsConstructor
    public static class SimilarityRequestDTO {

        private Long challengeId;
        private List<TrackRequest.NodeDTO> nodes;
    }
}
