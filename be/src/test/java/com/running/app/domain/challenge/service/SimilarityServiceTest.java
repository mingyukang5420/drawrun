package com.running.app.domain.challenge.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.track.dto.TrackRequest;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class SimilarityServiceTest {

    private SimilarityService similarityService;

    // 서울 강남 근처 기준점
    private static final double LAT0 = 37.50;
    private static final double LNG0 = 127.00;

    @BeforeEach
    void setUp() {
        similarityService = new SimilarityService(new ObjectMapper());
    }

    /**
     * 물리적 정사각형 경로 생성: 한 변이 sideMeter인 정사각형.
     * ENU에서 dE = dN이 되도록 cos(lat) 보정 적용.
     * pointsPerSide: 각 변당 GPS 점 수 (코너 포함)
     */
    private List<TrackRequest.NodeDTO> buildPhysicalSquareNodes(
            double lat0, double lng0, double sideMeter, int pointsPerSide) {

        double dLat = sideMeter / 111320.0;
        double dLng = sideMeter / (Math.cos(Math.toRadians(lat0)) * 111320.0);

        List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
        // SW → SE (bottom, going east)
        for (int i = 0; i < pointsPerSide; i++) {
            double t = (double) i / (pointsPerSide - 1);
            nodes.add(nodeOf(lat0, lng0 + t * dLng));
        }
        // SE → NE (right, going north)
        for (int i = 1; i < pointsPerSide; i++) {
            double t = (double) i / (pointsPerSide - 1);
            nodes.add(nodeOf(lat0 + t * dLat, lng0 + dLng));
        }
        // NE → NW (top, going west)
        for (int i = 1; i < pointsPerSide; i++) {
            double t = (double) i / (pointsPerSide - 1);
            nodes.add(nodeOf(lat0 + dLat, lng0 + dLng - t * dLng));
        }
        // NW → SW (left, going south)
        for (int i = 1; i < pointsPerSide - 1; i++) {
            double t = (double) i / (pointsPerSide - 1);
            nodes.add(nodeOf(lat0 + dLat - t * dLat, lng0));
        }
        return nodes;
    }

    private TrackRequest.NodeDTO nodeOf(double lat, double lng) {
        return new TrackRequest.NodeDTO(lat, lng);
    }

    /** 이미지 좌표 [0,1] 기준 정사각형 폴리곤 JSON */
    private String squarePolygon() {
        // 이미지 가운데에 꽉 찬 정사각형 (ChallengeOutlineExtractService 출력 형식)
        return "[[0.1,0.1],[0.5,0.1],[0.9,0.1],[0.9,0.5],[0.9,0.9],"
             + "[0.5,0.9],[0.1,0.9],[0.1,0.5],[0.1,0.1]]";
    }

    @Test
    void 정사각형_챌린지_정사각형_경로_고득점() {
        String polygon = squarePolygon();
        List<TrackRequest.NodeDTO> nodes =
                buildPhysicalSquareNodes(LAT0, LNG0, 200.0, 20);

        Double score = similarityService.calculate(polygon, nodes);

        assertThat(score)
                .as("정사각형 vs 정사각형은 85점 이상이어야 함, 실제: %s", score)
                .isGreaterThanOrEqualTo(85.0);
    }

    @Test
    void 정사각형_챌린지_소음_있는_정사각형_경로_고득점() {
        // GPS 노이즈(최대 ±3m)가 있어도 정사각형은 고득점이어야 함
        String polygon = squarePolygon();

        double sideMeter = 200.0;
        double dLat = sideMeter / 111320.0;
        double dLng = sideMeter / (Math.cos(Math.toRadians(LAT0)) * 111320.0);
        double noiseLat = 3.0 / 111320.0; // 3m 노이즈
        double noiseLng = 3.0 / (Math.cos(Math.toRadians(LAT0)) * 111320.0);

        List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
        int pts = 20;
        // 바닥 변 (SW→SE) + 약간의 노이즈
        for (int i = 0; i < pts; i++) {
            double t = (double) i / (pts - 1);
            double jitter = (i % 2 == 0 ? 1 : -1) * noiseLat;
            nodes.add(nodeOf(LAT0 + jitter, LNG0 + t * dLng));
        }
        // 오른쪽 변 (SE→NE)
        for (int i = 1; i < pts; i++) {
            double t = (double) i / (pts - 1);
            double jitter = (i % 2 == 0 ? 1 : -1) * noiseLng;
            nodes.add(nodeOf(LAT0 + t * dLat, LNG0 + dLng + jitter));
        }
        // 위 변 (NE→NW)
        for (int i = 1; i < pts; i++) {
            double t = (double) i / (pts - 1);
            double jitter = (i % 2 == 0 ? 1 : -1) * noiseLat;
            nodes.add(nodeOf(LAT0 + dLat + jitter, LNG0 + dLng - t * dLng));
        }
        // 왼쪽 변 (NW→SW)
        for (int i = 1; i < pts - 1; i++) {
            double t = (double) i / (pts - 1);
            double jitter = (i % 2 == 0 ? 1 : -1) * noiseLng;
            nodes.add(nodeOf(LAT0 + dLat - t * dLat, LNG0 + jitter));
        }

        Double score = similarityService.calculate(polygon, nodes);

        assertThat(score)
                .as("GPS 노이즈 있는 정사각형은 80점 이상이어야 함, 실제: %s", score)
                .isGreaterThanOrEqualTo(80.0);
    }

    @Test
    void 정사각형_챌린지_반대방향_정사각형_경로_고득점() {
        // 반시계 방향으로 달린 경우 (mirror 처리)
        String polygon = squarePolygon();
        List<TrackRequest.NodeDTO> base =
                buildPhysicalSquareNodes(LAT0, LNG0, 200.0, 20);

        // 순서 반전
        List<TrackRequest.NodeDTO> reversed = new ArrayList<>(base);
        java.util.Collections.reverse(reversed);

        Double score = similarityService.calculate(polygon, reversed);

        assertThat(score)
                .as("반대 방향 정사각형은 85점 이상이어야 함, 실제: %s", score)
                .isGreaterThanOrEqualTo(85.0);
    }

    @Test
    void 실제_GPS_데이터_이상정사각형_챌린지_진단() {
        // challengeId=2에서 44.4점이 나온 실제 GPS 노드 → 이상적 정사각형 챌린지와 비교
        // 이 테스트는 GPS 경로 자체의 품질을 진단함 (챌린지 폴리곤 품질과 분리)
        String idealSquare = squarePolygon();

        List<TrackRequest.NodeDTO> actualNodes = List.of(
            nodeOf(37.48185385982559, 126.97812472139583),
            nodeOf(37.48185385982559, 126.97846665680339),
            nodeOf(37.481817680948765, 126.97877059938708),
            nodeOf(37.481841800201764, 126.97905934484248),
            nodeOf(37.4818297405765, 126.97939368168528),
            nodeOf(37.48181165113465, 126.97950766015396),
            nodeOf(37.48207696251106, 126.97950006158925),
            nodeOf(37.4823543324884, 126.97950766015396),
            nodeOf(37.48262567168766, 126.97953045584825),
            nodeOf(37.48284274233714, 126.97957604723547),
            nodeOf(37.48283068287341, 126.97932529460377),
            nodeOf(37.48284274233714, 126.97912773192411),
            nodeOf(37.48284877206852, 126.97879339508131),
            nodeOf(37.48284877206852, 126.97853504388485),
            nodeOf(37.48287892071764, 126.97835267833466),
            nodeOf(37.48289700990108, 126.97820830560693),
            nodeOf(37.482728177350864, 126.97820830560693),
            nodeOf(37.48258949318456, 126.97819310847746),
            nodeOf(37.482426689704866, 126.97814751709018),
            nodeOf(37.482251826312336, 126.97814751709018),
            nodeOf(37.48212520084189, 126.97812472139583)
        );

        Double score = similarityService.calculate(idealSquare, actualNodes);
        System.out.printf("실제 GPS + 이상적 정사각형 챌린지 점수: %.2f%n", score);

        // 알고리즘 문제인지(점수 낮음) vs 챌린지 폴리곤 문제인지 구분
        // GPS 경로는 종횡비 1.06:1, 단 시작-끝 30m 미결합(왼쪽 변 25% 누락)
        assertThat(score)
            .as("실제 GPS 경로는 정사각형과 60점 이상 일치해야 함 (왼쪽 변 25%% 누락 + 하단 노이즈 감안), 실제: %.2f", score)
            .isGreaterThanOrEqualTo(60.0);
    }

    @Test
    void 완전히_다른_형태_저득점() {
        // 정사각형 챌린지에 직선 경로 → 낮은 점수
        String polygon = squarePolygon();

        List<TrackRequest.NodeDTO> line = new ArrayList<>();
        for (int i = 0; i < 30; i++) {
            double t = (double) i / 29;
            line.add(nodeOf(LAT0 + t * 0.002, LNG0));
        }

        Double score = similarityService.calculate(polygon, line);

        assertThat(score)
                .as("직선 경로 vs 정사각형은 50점 미만이어야 함, 실제: %s", score)
                .isLessThan(50.0);
    }
}
