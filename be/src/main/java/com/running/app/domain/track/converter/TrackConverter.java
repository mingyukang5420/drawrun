package com.running.app.domain.track.converter;

import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.MultiLineString;

import java.util.Arrays;
import java.util.List;
import java.util.stream.IntStream;

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

    public static List<TrackRequest.NodeDTO> toNodeDTOList(
            Track track
    ) {
        MultiLineString geom = track.getGeom();

        return IntStream.range(0, geom.getNumGeometries())
                .mapToObj(geom::getGeometryN)
                .flatMap(geometry -> Arrays.stream(geometry.getCoordinates()))
                .map(TrackConverter::toNodeDTO)
                .toList();
    }

    private static TrackRequest.NodeDTO toNodeDTO(
            Coordinate coordinate
    ) {
        return new TrackRequest.NodeDTO(
                coordinate.getY(),
                coordinate.getX()
        );
    }
}
