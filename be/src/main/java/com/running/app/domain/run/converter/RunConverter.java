package com.running.app.domain.run.converter;

import com.running.app.domain.run.dto.RunResponse;
import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import java.util.List;

public class RunConverter {

    public static RunResponse.StartDTO toStartResponse(
            Track track
    ) {
        return RunResponse.StartDTO.builder()
                .nodes(TrackConverter.toNodeDTOList(track))
                .build();
    }

    // 자유러닝일때는 nodes -> null
    public static RunResponse.StartDTO toFreeRunStartResponse() {
        return RunResponse.StartDTO.builder()
                .nodes(null)
                .build();
    }
}
