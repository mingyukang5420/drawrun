package com.running.app.domain.track.converter;

import com.running.app.domain.track.entity.Track;
import org.locationtech.jts.geom.MultiLineString;

public class TrackConverter {

    public static Track toTrack(
            MultiLineString geom,
            Double distance,
            String trackImageUrl
    ) {
        return Track.builder()
                .geom(geom)
                .distance(distance)
                .trackImageUrl(trackImageUrl)
                .build();
    }
}
