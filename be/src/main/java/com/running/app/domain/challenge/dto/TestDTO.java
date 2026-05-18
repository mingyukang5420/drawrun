package com.running.app.domain.challenge.dto;

import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@NoArgsConstructor
public class TestDTO {

    private String testKey;
    private String imgString;

    @Getter
    @NoArgsConstructor
    public static class SimilarityRequestDTO {
        private String testKey;
        private Long challengeId;
        private List<TrackRequest.NodeDTO> nodes;
    }
}
