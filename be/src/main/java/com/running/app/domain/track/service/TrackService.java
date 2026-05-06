package com.running.app.domain.track.service;

import com.running.app.domain.track.converter.TrackConverter;
import com.running.app.domain.track.dto.TrackRequest;
import com.running.app.domain.track.entity.Track;
import com.running.app.domain.track.repository.TrackRepository;
import com.running.app.global.response.exception.GeneralException;
import com.running.app.global.response.status.ErrorStatus;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.LineString;
import org.locationtech.jts.geom.MultiLineString;
import org.locationtech.jts.geom.PrecisionModel;
import org.locationtech.jts.io.WKTWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true) //읽기 전용으로 두기
public class TrackService {

    private static final int SRID = 4326;

    private static final String PENDING_TRACK_IMAGE_URL = "썸네일 url 저장 로직 추가 예정";

    private final TrackRepository trackRepository;

    @Value("${app.upload.track-image-url-prefix}")
    private String trackImageUrlPrefix;

    // 자유러닝용 — 클라이언트가 GPS 누적 거리(distance)와 트랙 이미지 URL을 보내줌
    @Transactional
    public Track createTrack(
            List<TrackRequest.NodeDTO> nodes,
            Double distance,
            String trackImageUrl
    ) {
        validateTrackImageUrl(trackImageUrl);

        MultiLineString geom = createMultiLineString(nodes);

        Track track = TrackConverter.toTrack(
                geom,
                distance,
                trackImageUrl
        );

        return trackRepository.save(track);
    }

    // 에디터 저장용 — 클라이언트가 distance를 모르므로 PostGIS로 자동 계산.
    // 트랙 이미지는 추후 썸네일 생성 로직 추가 예정 — 그 전까지 sentinel 문자열로 채움.
    @Transactional
    public Track createTrackFromEditor(MultiLineString geom) {
        String wkt = new WKTWriter().write(geom);
        Double distanceMeters = trackRepository.calculateLengthMeters(wkt);
        Double distanceKm = distanceMeters / 1000.0;

        Track track = TrackConverter.toTrack(geom, distanceKm, PENDING_TRACK_IMAGE_URL);

        return trackRepository.save(track);
    }

    // 좌표 리스트 → MultiLineString 변환. EditorService 도 호출하므로 public
    public MultiLineString createMultiLineString(List<TrackRequest.NodeDTO> nodes) {
        GeometryFactory geometryFactory = new GeometryFactory(
                // Double 정밀도 사용
                new PrecisionModel(),
                SRID
        );

        //lat-lng => lng-lat 순서 변환
        //Coordinate -> JTS에서 좌표 한 점을 표현하는 객체
        Coordinate[] coordinates = nodes.stream()
                .map(node -> new Coordinate(node.getLng(), node.getLat()))
                .toArray(Coordinate[]::new);

        LineString lineString = geometryFactory.createLineString(coordinates);

        //LineString -> MultiLineString
        return geometryFactory.createMultiLineString(new LineString[]{lineString});
    }

    // 이미지 경로 검증 로직
    private void validateTrackImageUrl(String trackImageUrl) {
        // 비어 있지 않은지 체크
        if (trackImageUrl == null || trackImageUrl.isBlank()) {
            throw new GeneralException(ErrorStatus.INVALID_TRACK_IMAGE_URL);
        }
        // 설정한 prefix로 시작하는지 체크
        String normalizedPrefix = normalizeUrlPrefix(trackImageUrlPrefix);
        String normalizedTrackImageUrl = trackImageUrl.trim();

        if (!normalizedTrackImageUrl.startsWith(normalizedPrefix + "/")) {
            throw new GeneralException(ErrorStatus.INVALID_TRACK_IMAGE_URL, trackImageUrl);
        }
        // ".." 같은 잘못된 경로가 있는지 체크
        if (normalizedTrackImageUrl.contains("..")) {
            throw new GeneralException(ErrorStatus.INVALID_TRACK_IMAGE_URL, trackImageUrl);
        }
    }

    private String normalizeUrlPrefix(String urlPrefix) {
        String normalized = urlPrefix.trim();

        if (!normalized.startsWith("/")) {
            normalized = "/" + normalized;
        }

        if (normalized.endsWith("/")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }

        return normalized;
    }
}
