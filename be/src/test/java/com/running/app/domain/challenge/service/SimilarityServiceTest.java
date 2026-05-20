package com.running.app.domain.challenge.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.track.dto.TrackRequest;
import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;

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

    @Test
    void 사각형_챌린지_파라미터_튜닝() throws Exception {
        File squareImg = new File("C:/Users/SSAFY/Desktop/uploads/challenge/3c207647-a50b-47b2-b19f-1ff03e72e3c5.png");
        File dogImg    = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        org.junit.jupiter.api.Assumptions.assumeTrue(squareImg.exists() && dogImg.exists(), "이미지 파일 없음 — 로컬 진단 전용");

        ChallengeOutlineExtractService extractor = new ChallengeOutlineExtractService(new ObjectMapper());

        String squarePoly = extractor.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(squareImg.toPath())));
        String dogPoly    = extractor.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(dogImg.toPath())));

        // 사각형 챌린지 - 틀린 경로 (낮은 점수 기대)
        List<TrackRequest.NodeDTO> squareBad = List.of(
            nodeOf(37.496222615546344, 127.03535667541081),
            nodeOf(37.495754571825934, 127.03438074460001),
            nodeOf(37.49543119445106,  127.03464885746011),
            nodeOf(37.49501846076752,  127.03489552129145),
            nodeOf(37.49523972034542,  127.03559261472772),
            nodeOf(37.49575882678204,  127.03548000732648),
            nodeOf(37.49618636594446,  127.03537847665449)
        );

        // 사각형 챌린지 - 올바른 경로 (높은 점수 기대)
        List<TrackRequest.NodeDTO> squareGood = List.of(
            nodeOf(37.4935496881142,   127.03178984305464),
            nodeOf(37.49210720143162,  127.03248693649095),
            nodeOf(37.49259654369411,  127.03413314945202),
            nodeOf(37.49404327597977,  127.03343605601576),
            nodeOf(37.493562429482104, 127.03184093899725)
        );

        // 강아지 챌린지 경로
        List<TrackRequest.NodeDTO> dogNodes = List.of(
            nodeOf(37.501576940717065, 127.03991744632508),
            nodeOf(37.50127486176697,  127.03999251792591),
            nodeOf(37.5009387443156,   127.04023918175722),
            nodeOf(37.501411010177435, 127.04156365928617),
            nodeOf(37.50134293600322,  127.04163336862977),
            nodeOf(37.50176414396008,  127.04295248390156),
            nodeOf(37.501313153532486, 127.04318842321844),
            nodeOf(37.50109191194942,  127.04242162043852),
            nodeOf(37.50019417495286,  127.0428666877863),
            nodeOf(37.499883580966994, 127.04178887408865),
            nodeOf(37.50041541919596,  127.04156365928617),
            nodeOf(37.50010482613039,  127.04061990201859),
            nodeOf(37.4996155330639,   127.04083975456389),
            nodeOf(37.49946661714639,  127.04034642690128),
            nodeOf(37.50039414573954,  127.03992280858229),
            nodeOf(37.50014311849598,  127.03900586260072),
            nodeOf(37.50050051296108,  127.03885035714184),
            nodeOf(37.500823868384025, 127.03865195362533),
            nodeOf(37.50105362007043,  127.03934368480445),
            nodeOf(37.50135536800712,  127.03922961020126),
            nodeOf(37.50159139983933,  127.03995676543026)
        );

        System.out.printf("사각형 polygon 점 수: %d%n",
            new ObjectMapper().readValue(squarePoly, new com.fasterxml.jackson.core.type.TypeReference<java.util.List<?>>(){}).size());
        System.out.printf("강아지 polygon 점 수: %d%n",
            new ObjectMapper().readValue(dogPoly, new com.fasterxml.jackson.core.type.TypeReference<java.util.List<?>>(){}).size());

        // CSV 실제 런 노드 로드
        File csvFile = new File("C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_151547.csv");
        List<TrackRequest.NodeDTO> csvNodes = new ArrayList<>();
        if (csvFile.exists()) {
            try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(csvFile))) {
                br.readLine(); // header
                String line;
                while ((line = br.readLine()) != null) {
                    String[] cols = line.split(",", -1);
                    if (!"GPS".equals(cols[2])) continue;
                    if (cols[11].isEmpty() || cols[12].isEmpty()) continue;
                    csvNodes.add(nodeOf(Double.parseDouble(cols[11]), Double.parseDouble(cols[12])));
                }
            }
        }

        double[] buffers     = {0.02, 0.03, 0.04, 0.05};
        double[] softFactors = {1.5, 2.0, 3.0, 4.0};

        System.out.println("\nBUFFER\tSOFT\t사각형(나쁨)\t사각형(좋음)\t강아지(21)\t강아지(CSV)");
        for (double buf : buffers) {
            for (double sf : softFactors) {
                double s1 = calcWithParams(squarePoly, squareBad,  buf, sf);
                double s2 = calcWithParams(squarePoly, squareGood, buf, sf);
                double s3 = calcWithParams(dogPoly,    dogNodes,   buf, sf);
                double s4 = csvNodes.isEmpty() ? -1 : calcWithParams(dogPoly, csvNodes, buf, sf);
                System.out.printf("%.2f\t%.1f\t%.2f\t\t%.2f\t\t%.2f\t\t%.2f%n", buf, sf, s1, s2, s3, s4);
            }
        }
    }

    /** GPS 경로의 물리적 bbox 최장 변 (미터) */
    private double physicalBboxMeters(List<TrackRequest.NodeDTO> nodes) {
        double LNG_RATIO = Math.cos(Math.toRadians(37.5));
        double minLat = Double.MAX_VALUE, maxLat = -Double.MAX_VALUE;
        double minLng = Double.MAX_VALUE, maxLng = -Double.MAX_VALUE;
        for (TrackRequest.NodeDTO n : nodes) {
            minLat = Math.min(minLat, n.getLat()); maxLat = Math.max(maxLat, n.getLat());
            minLng = Math.min(minLng, n.getLng()); maxLng = Math.max(maxLng, n.getLng());
        }
        double latM = (maxLat - minLat) * 111320;
        double lngM = (maxLng - minLng) * LNG_RATIO * 111320;
        return Math.max(latM, lngM);
    }

    @Test
    void 고정_물리버퍼_시뮬레이션() throws Exception {
        File dogImg    = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        File squareImg = new File("C:/Users/SSAFY/Desktop/uploads/challenge/3c207647-a50b-47b2-b19f-1ff03e72e3c5.png");
        org.junit.jupiter.api.Assumptions.assumeTrue(dogImg.exists() && squareImg.exists(), "이미지 없음");

        ChallengeOutlineExtractService ext = new ChallengeOutlineExtractService(new ObjectMapper());
        String dogPoly    = ext.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(dogImg.toPath())));
        String squarePoly = ext.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(squareImg.toPath())));

        // 런 데이터 로드
        java.util.Map<String, Object[]> runs = new java.util.LinkedHashMap<>();
        // {polygon, nodes}
        List<TrackRequest.NodeDTO> st = new ArrayList<>();
        try (java.io.BufferedReader br = new java.io.BufferedReader(
                new java.io.FileReader("C:/Users/SSAFY/Desktop/gps-improvement/small_truth_v1.csv"))) {
            br.readLine();
            String line;
            while ((line = br.readLine()) != null) {
                if (line.isBlank()) continue;
                String[] c = line.split(",");
                st.add(nodeOf(Double.parseDouble(c[1]), Double.parseDouble(c[2])));
            }
        }
        runs.put("small_truth(99)", new Object[]{squarePoly, st});

        java.util.Map<String, String[]> csvDef = new java.util.LinkedHashMap<>();
        csvDef.put("161123_small(63)", new String[]{"C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_161123.csv", "square"});
        csvDef.put("151547_dog(187)", new String[]{"C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_151547.csv", "dog"});
        csvDef.put("161641_sq_good(37)", new String[]{"C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_161641.csv", "square"});
        for (var e : csvDef.entrySet()) {
            List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
            try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(e.getValue()[0]))) {
                br.readLine(); String line;
                while ((line = br.readLine()) != null) {
                    String[] c = line.split(",", -1);
                    if (!"GPS".equals(c[2]) || c[11].isEmpty() || c[12].isEmpty()) continue;
                    nodes.add(nodeOf(Double.parseDouble(c[11]), Double.parseDouble(c[12])));
                }
            }
            runs.put(e.getKey(), new Object[]{"dog".equals(e.getValue()[1]) ? dogPoly : squarePoly, nodes});
        }

        // 162029 버그 제거본 (lng > 127.0395)
        List<TrackRequest.NodeDTO> sq_bad = new ArrayList<>();
        try (java.io.BufferedReader br = new java.io.BufferedReader(
                new java.io.FileReader("C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_162029.csv"))) {
            br.readLine(); String line;
            while ((line = br.readLine()) != null) {
                String[] c = line.split(",", -1);
                if (!"GPS".equals(c[2]) || c[11].isEmpty() || c[12].isEmpty()) continue;
                if (Double.parseDouble(c[12]) > 127.0395)
                    sq_bad.add(nodeOf(Double.parseDouble(c[11]), Double.parseDouble(c[12])));
            }
        }
        runs.put("162029_sq_bad_fix(11)", new Object[]{squarePoly, sq_bad});

        double SOFT = 2.0;
        double[] targetMeters = {5.0, 10.0, 15.0, 20.0};

        // bbox 정보 출력
        System.out.println("=== 런별 물리 bbox ===");
        System.out.printf("%-25s %8s %10s %10s %10s %10s%n",
            "런", "bbox(m)", "buf@5m", "buf@10m", "buf@15m", "buf@20m");
        for (var e : runs.entrySet()) {
            @SuppressWarnings("unchecked")
            List<TrackRequest.NodeDTO> nodes = (List<TrackRequest.NodeDTO>) e.getValue()[1];
            double bbox = physicalBboxMeters(nodes);
            System.out.printf("%-25s %8.1f %10.4f %10.4f %10.4f %10.4f%n",
                e.getKey(), bbox,
                5.0/bbox, 10.0/bbox, 15.0/bbox, 20.0/bbox);
        }

        // 고정 물리 버퍼별 점수 예측
        System.out.printf("%n=== 고정 물리 버퍼 적용 시 예측 점수 (SOFT=%.1f) ===%n", SOFT);
        System.out.printf("%-25s", "런");
        for (double tm : targetMeters) System.out.printf(" %10s", (int)tm + "m 버퍼");
        System.out.printf(" %10s%n", "현재(5%)");
        for (var e : runs.entrySet()) {
            @SuppressWarnings("unchecked")
            List<TrackRequest.NodeDTO> nodes = (List<TrackRequest.NodeDTO>) e.getValue()[1];
            String poly = (String) e.getValue()[0];
            double bbox = physicalBboxMeters(nodes);
            System.out.printf("%-25s", e.getKey());
            for (double tm : targetMeters) {
                double dynBuf = tm / bbox;
                System.out.printf(" %10.2f", calcWithParams(poly, nodes, dynBuf, SOFT));
            }
            System.out.printf(" %10.2f%n", calcWithParams(poly, nodes, 0.05, SOFT));
        }
    }

    @Test
    void 전체_런_파라미터_튜닝() throws Exception {
        File dogImg    = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        File squareImg = new File("C:/Users/SSAFY/Desktop/uploads/challenge/3c207647-a50b-47b2-b19f-1ff03e72e3c5.png");
        org.junit.jupiter.api.Assumptions.assumeTrue(dogImg.exists() && squareImg.exists(), "이미지 없음");

        ChallengeOutlineExtractService ext = new ChallengeOutlineExtractService(new ObjectMapper());
        String dogPoly    = ext.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(dogImg.toPath())));
        String squarePoly = ext.extract(Base64.getEncoder().encodeToString(Files.readAllBytes(squareImg.toPath())));

        // small_truth: CSV (lat,lng 컬럼)
        List<TrackRequest.NodeDTO> smallTruth = new ArrayList<>();
        File stFile = new File("C:/Users/SSAFY/Desktop/gps-improvement/small_truth_v1.csv");
        if (stFile.exists()) {
            try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(stFile))) {
                br.readLine();
                String line;
                while ((line = br.readLine()) != null) {
                    if (line.isBlank()) continue;
                    String[] c = line.split(",");
                    smallTruth.add(nodeOf(Double.parseDouble(c[1]), Double.parseDouble(c[2])));
                }
            }
        }

        java.util.Map<String, List<TrackRequest.NodeDTO>> runs = new java.util.LinkedHashMap<>();
        runs.put("small_truth(99)", smallTruth);

        // GPS debug CSV 로드 (filtered_lat/lng)
        java.util.Map<String, String> csvFiles = new java.util.LinkedHashMap<>();
        csvFiles.put("161123_dog",      "C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_161123.csv");
        csvFiles.put("151547_dog",      "C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_151547.csv");
        csvFiles.put("161641_sq_good",  "C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_161641.csv");
        csvFiles.put("162029_sq_bad",   "C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_162029.csv");
        for (java.util.Map.Entry<String, String> e : csvFiles.entrySet()) {
            List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
            try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(e.getValue()))) {
                br.readLine();
                String line;
                while ((line = br.readLine()) != null) {
                    String[] c = line.split(",", -1);
                    if (!"GPS".equals(c[2]) || c[11].isEmpty() || c[12].isEmpty()) continue;
                    nodes.add(nodeOf(Double.parseDouble(c[11]), Double.parseDouble(c[12])));
                }
            }
            runs.put(e.getKey() + "(" + nodes.size() + ")", nodes);
        }

        // 162029: lng > 127.0395 구간만 (버그 구간 제외)
        List<TrackRequest.NodeDTO> badSquareFiltered = new ArrayList<>();
        try (java.io.BufferedReader br = new java.io.BufferedReader(
                new java.io.FileReader("C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_162029.csv"))) {
            br.readLine();
            String line;
            while ((line = br.readLine()) != null) {
                String[] c = line.split(",", -1);
                if (!"GPS".equals(c[2]) || c[11].isEmpty() || c[12].isEmpty()) continue;
                double lng = Double.parseDouble(c[12]);
                if (lng > 127.0395) badSquareFiltered.add(nodeOf(Double.parseDouble(c[11]), lng));
            }
        }
        runs.put("162029_sq_bad_fix(" + badSquareFiltered.size() + ")", badSquareFiltered);

        // 폴리곤 할당: 151547=dog, 나머지=square
        java.util.Map<String, String> polyMap = new java.util.LinkedHashMap<>();
        for (String key : runs.keySet()) {
            polyMap.put(key, key.contains("151547") ? "dog" : "square");
        }

        double[] buffers     = {0.02, 0.03, 0.04, 0.05};
        double[] softFactors = {1.5, 2.0, 3.0};

        // 헤더
        System.out.print(String.format("%-8s %-6s", "BUFFER", "SOFT"));
        for (String name : runs.keySet()) System.out.print(String.format(" %-26s", name));
        System.out.println();

        for (double buf : buffers) {
            for (double sf : softFactors) {
                System.out.print(String.format("%-8.2f %-6.1f", buf, sf));
                for (java.util.Map.Entry<String, List<TrackRequest.NodeDTO>> e : runs.entrySet()) {
                    String poly = "dog".equals(polyMap.get(e.getKey())) ? dogPoly : squarePoly;
                    double s = calcWithParams(poly, e.getValue(), buf, sf);
                    System.out.print(String.format(" %-26.2f", s));
                }
                System.out.println();
            }
        }
    }

    @Test
    void 강아지_챌린지_CSV런_파라미터_튜닝() throws Exception {
        File dogImg = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        File csvFile = new File("C:/Users/SSAFY/Desktop/gps-improving/gps_debug_20260520_151547.csv");
        org.junit.jupiter.api.Assumptions.assumeTrue(dogImg.exists() && csvFile.exists(), "파일 없음 — 로컬 진단 전용");

        String base64 = Base64.getEncoder().encodeToString(Files.readAllBytes(dogImg.toPath()));
        ChallengeOutlineExtractService extractor = new ChallengeOutlineExtractService(new ObjectMapper());
        String polygonPoints = extractor.extract(base64);

        // CSV에서 filtered GPS 노드 추출 (filtered_lat, filtered_lng 컬럼)
        List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
        try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(csvFile))) {
            String header = br.readLine();
            String[] headers = header.split(",");
            int typeIdx = 2, filtLatIdx = 11, filtLngIdx = 12;
            String line;
            while ((line = br.readLine()) != null) {
                String[] cols = line.split(",", -1);
                if (!"GPS".equals(cols[typeIdx])) continue;
                if (cols[filtLatIdx].isEmpty() || cols[filtLngIdx].isEmpty()) continue;
                nodes.add(nodeOf(Double.parseDouble(cols[filtLatIdx]), Double.parseDouble(cols[filtLngIdx])));
            }
        }

        System.out.printf("CSV GPS 노드 수: %d%n", nodes.size());

        double[] buffers     = {0.02, 0.03, 0.04, 0.05, 0.06, 0.07};
        double[] softFactors = {1.5, 2.0, 3.0, 4.0};
        System.out.println("\nBUFFER\tSOFT\t점수");
        for (double buf : buffers) {
            for (double sf : softFactors) {
                double score = calcWithParams(polygonPoints, nodes, buf, sf);
                System.out.printf("%.2f\t%.1f\t%.2f%n", buf, sf, score);
            }
        }

        Double current = similarityService.calculate(polygonPoints, nodes);
        System.out.printf("%n현재 파라미터 (BUFFER=0.05, SOFT=4.0) 점수: %.2f%n", current);
    }

    @Test
    void 강아지_챌린지_실제런_MULTILINESTRING() throws Exception {
        File dogImg = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        org.junit.jupiter.api.Assumptions.assumeTrue(dogImg.exists(), "이미지 파일 없음 — 로컬 진단 전용");

        String base64 = Base64.getEncoder().encodeToString(Files.readAllBytes(dogImg.toPath()));
        ChallengeOutlineExtractService extractor = new ChallengeOutlineExtractService(new ObjectMapper());
        String polygonPoints = extractor.extract(base64);

        // WKT MULTILINESTRING 파싱 (lng lat → NodeDTO(lat, lng))
        String wkt = "MULTILINESTRING ((127.039463 37.5014532, 127.03947972240813 37.50146386053518, 127.03947309983377 37.50146731608515, 127.03945911985869 37.50146635367238, 127.03926198976927 37.50146901632602, 127.0392707877252 37.50148285891562, 127.03914469912 37.50168844376964, 127.03914523261199 37.50170527512675, 127.03919022338292 37.50181900471862, 127.03966370835099 37.501643981608055, 127.03971419358012 37.50165534729949, 127.0397609822644 37.50166604964803, 127.03980529765339 37.50167752892355, 127.03984644981354 37.501690114669366, 127.03989217839398 37.5017032119028, 127.03994563321939 37.50171452727633, 127.04000250038338 37.50172802756074, 127.04017779705391 37.50177652975432, 127.04020377880227 37.501796636806674, 127.04023682676836 37.5018232151063, 127.04028479977433 37.5018506968195, 127.04044266754143 37.50192132965067, 127.04047942537301 37.50193223684891, 127.041083923119 37.501402253273824, 127.04110993233326 37.50139481272024, 127.04143212630191 37.50141142945624, 127.04146392821035 37.501410784095896, 127.04153905243427 37.50142606702245, 127.04157799185174 37.501449987961266, 127.04160985953976 37.501480710453734, 127.0416379924076 37.50153558511716, 127.04162800611113 37.50158072619792, 127.04160904516002 37.501626422692645, 127.04158867661234 37.501680111968064, 127.04157492502796 37.50173350620374, 127.04154724956896 37.50177908557895, 127.04146812813218 37.50189774603686, 127.04144890967714 37.50193402811691, 127.04143060001664 37.50197153449528, 127.04305101844753 37.50168012834317, 127.04306227436555 37.50155490099374, 127.04305813304609 37.50151214575902, 127.04306718560068 37.501465952137, 127.04307333853603 37.501421031713676, 127.04307183634718 37.50137904837643, 127.04307437420131 37.5013404817273, 127.0430589844137 37.501307441807114, 127.04301530227612 37.5012879960217, 127.04297223131556 37.50125524923891, 127.04293249311607 37.501220360035504, 127.0428885666158 37.501196769482135, 127.0428303889353 37.50119249550841, 127.04264599495428 37.50120636055347, 127.0426000426173 37.50119134079142, 127.04253970721282 37.50116940173111, 127.04247950978203 37.50113630035083, 127.0424652171323 37.50108869165349, 127.04246754766162 37.50104191817429, 127.04245742584256 37.5010001183859, 127.0424491078596 37.50085633990868, 127.04241197591145 37.50085531237501, 127.04238759709276 37.50083733040302, 127.04238776650546 37.50081589543967, 127.04239800506521 37.50078443326811, 127.04248573824066 37.50065254034023, 127.04252450611607 37.500631161770485, 127.04256857129963 37.5006223151494, 127.04259023354324 37.50060265254083, 127.04259633285443 37.50057953918805, 127.04267061290743 37.50042381273644, 127.04269076004456 37.50039324981028, 127.04270837832547 37.500345708839305, 127.04272293776388 37.500291817043475, 127.04271431516759 37.500241481709594, 127.04270363814231 37.50019881531311, 127.04268983568102 37.50016629694075, 127.04265211327797 37.50016006301703, 127.0425986704627 37.50015167497013, 127.042547157557 37.50013257540734, 127.04249605484847 37.50011433401798, 127.04243412698295 37.50008063374547, 127.04228313669837 37.50001306439181, 127.04224841972011 37.49998865939817, 127.04220435857968 37.49996633570307, 127.04215362143802 37.49995005165709, 127.04209674887414 37.49993962863866, 127.04203667309382 37.49993950904109, 127.04197541246648 37.499933604632574, 127.0419180925474 37.49992872784747, 127.04186666706097 37.49994177178124, 127.04182073009954 37.4999723486538, 127.0417821400223 37.50000163714701, 127.0417540392622 37.500033951555764, 127.04173144298703 37.50006938780266, 127.04166279635601 37.50018266599236, 127.04163860956284 37.50021802806529, 127.04160789597717 37.50025911988562, 127.04157741943365 37.50030531828466, 127.04153780244867 37.50034873774513, 127.04148396378865 37.50034981328318, 127.04142607486011 37.50033556665031, 127.04137404813387 37.50032344730555, 127.04132386033798 37.500312509162015, 127.04127395483488 37.5002963898086, 127.04122287089876 37.5002793592726, 127.041094934375 37.500216890625, 127.04104855975643 37.50019495098606, 127.04098982293544 37.50016466771522, 127.04092955417845 37.50015157506829, 127.04087109813054 37.50014038995928, 127.04068355811023 37.500078362183444, 127.0406768687759 37.50003646116221, 127.0406711163805 37.49998984299372, 127.0406811250889 37.4999442558406, 127.0407235198773 37.49981746270087, 127.0407281984663 37.499785237911865, 127.0407302291886 37.499752537915384, 127.04074452412121 37.49972357376966, 127.04077695822842 37.49969893702925, 127.04082022935702 37.49964362365302, 127.04080797448685 37.499600369775585, 127.04077715302266 37.49957082235309, 127.04073646458372 37.49955210848011, 127.04068828058692 37.49953872327197, 127.0406341063049 37.49953227106907, 127.04059017974791 37.49953454288305, 127.04055104077341 37.49954653769517, 127.04044437839379 37.49967389398245, 127.04042500210826 37.49971867665806, 127.04039680139249 37.49976672775194, 127.04035939704008 37.49979889007713, 127.04031331134631 37.499820255838536, 127.04011002684175 37.49987106468205, 127.04007613617594 37.499891756300144, 127.04004352678743 37.499927896851226, 127.04002694211877 37.49996149676534, 127.03998354767654 37.500133654157885, 127.03996473199804 37.50017095033823, 127.03995511744543 37.500220823444884, 127.03993809491973 37.500265572686914, 127.03991547119861 37.50030991369211, 127.0398789478894 37.500339569094145, 127.03983507150858 37.500343787679796, 127.03977245169729 37.500337682271066, 127.03970730517403 37.50031875353662, 127.03963464131472 37.500297502688994, 127.03957477991466 37.5002910046798, 127.03951871025694 37.50028095702348, 127.03946102098399 37.50027275047896, 127.03932359329465 37.50024799961645, 127.03927252612348 37.500233974782944, 127.03908884603604 37.50018414001933, 127.039021311509 37.50018433500483, 127.03898642787726 37.500215733751205, 127.03895490221691 37.50025137433717, 127.03892396167939 37.50028501957426, 127.0389022441922 37.50032034603596, 127.03885775328214 37.50042618875712, 127.03882546234439 37.50043621823949, 127.03881081580542 37.500463691227395, 127.03872741204654 37.500548395463625, 127.0387213539777 37.50057905223359, 127.03871246253621 37.50061666524474, 127.03867063223439 37.50075001454158, 127.03865975291993 37.50078330846585, 127.03866555239688 37.500815999798405, 127.03869788135654 37.50083662984558, 127.03876115613728 37.50084370683919, 127.03882012344283 37.500846775379074, 127.03886423800436 37.50084029451732, 127.03890231461706 37.50085104782592, 127.03910628596367 37.500970645600546, 127.03924967500001 37.50101065, 127.03929323957078 37.50103157054985, 127.03930314705687 37.50106887397982, 127.03930408029032 37.5011112328427, 127.03921309830797 37.50123689332098, 127.03922070915746 37.501277482910524, 127.03925101646756 37.50131098422739, 127.03928975961699 37.50133159398345, 127.03933320877871 37.501340813517245, 127.03946924707694 37.50134094828861, 127.03951683995655 37.501337921158324, 127.03957083509528 37.50134152466923, 127.03962454446904 37.501353546164395, 127.03978742756571 37.50139806841332, 127.0398330317046 37.50143155495683))";

        String inner = wkt.replaceFirst("^MULTILINESTRING \\(\\(", "").replaceFirst("\\)\\)$", "");
        List<TrackRequest.NodeDTO> nodes = new ArrayList<>();
        for (String pair : inner.split(", ")) {
            String[] parts = pair.trim().split(" ");
            nodes.add(nodeOf(Double.parseDouble(parts[1]), Double.parseDouble(parts[0])));
        }

        System.out.printf("GPS 노드 수: %d%n", nodes.size());

        double[] buffers     = {0.05, 0.07};
        double[] softFactors = {3.0, 4.0, 5.0};
        System.out.println("BUFFER\tSOFT\t점수");
        for (double buf : buffers) {
            for (double sf : softFactors) {
                double score = calcWithParams(polygonPoints, nodes, buf, sf);
                System.out.printf("%.2f\t%.1f\t%.2f%n", buf, sf, score);
            }
        }

        Double current = similarityService.calculate(polygonPoints, nodes);
        System.out.printf("%n현재 파라미터 (BUFFER=0.05, SOFT=4.0) 점수: %.2f%n", current);
    }

    @Test
    void 강아지_챌린지_실제이미지_GPS_진단() throws Exception {
        File imageFile = new File("C:/Users/SSAFY/Desktop/uploads/challenge/7b3c2e15-8a4d-4963-b10f-62e5da914b78.png");
        org.junit.jupiter.api.Assumptions.assumeTrue(imageFile.exists(), "이미지 파일 없음 — 로컬 진단 전용");

        String base64 = Base64.getEncoder().encodeToString(Files.readAllBytes(imageFile.toPath()));
        ChallengeOutlineExtractService extractor = new ChallengeOutlineExtractService(new ObjectMapper());
        String polygonPoints = extractor.extract(base64);

        List<TrackRequest.NodeDTO> nodes = List.of(
            nodeOf(37.501576940717065, 127.03991744632508),
            nodeOf(37.50127486176697,  127.03999251792591),
            nodeOf(37.5009387443156,   127.04023918175722),
            nodeOf(37.501411010177435, 127.04156365928617),
            nodeOf(37.50134293600322,  127.04163336862977),
            nodeOf(37.50176414396008,  127.04295248390156),
            nodeOf(37.501313153532486, 127.04318842321844),
            nodeOf(37.50109191194942,  127.04242162043852),
            nodeOf(37.50019417495286,  127.0428666877863),
            nodeOf(37.499883580966994, 127.04178887408865),
            nodeOf(37.50041541919596,  127.04156365928617),
            nodeOf(37.50010482613039,  127.04061990201859),
            nodeOf(37.4996155330639,   127.04083975456389),
            nodeOf(37.49946661714639,  127.04034642690128),
            nodeOf(37.50039414573954,  127.03992280858229),
            nodeOf(37.50014311849598,  127.03900586260072),
            nodeOf(37.50050051296108,  127.03885035714184),
            nodeOf(37.500823868384025, 127.03865195362533),
            nodeOf(37.50105362007043,  127.03934368480445),
            nodeOf(37.50135536800712,  127.03922961020126),
            nodeOf(37.50159139983933,  127.03995676543026)
        );

        System.out.printf("polygon_points 점 수: %d%n",
            new com.fasterxml.jackson.core.type.TypeReference<java.util.List<java.util.List<Double>>>(){} instanceof Object
            ? new ObjectMapper().readValue(polygonPoints, new com.fasterxml.jackson.core.type.TypeReference<java.util.List<java.util.List<Double>>>(){}).size() : 0);

        // BUFFER / SOFT_FACTOR 조합별 점수 출력
        double[] buffers     = {0.05, 0.07, 0.10, 0.12};
        double[] softFactors = {3.0,  4.0,  5.0};
        System.out.println("BUFFER\tSOFT\t점수");
        for (double buf : buffers) {
            for (double sf : softFactors) {
                double score = calcWithParams(polygonPoints, nodes, buf, sf);
                System.out.printf("%.2f\t%.1f\t%.2f%n", buf, sf, score);
            }
        }

        Double scoreMoores = similarityService.calculate(polygonPoints, nodes);
        System.out.printf("%n현재 파라미터 (BUFFER=0.05, SOFT=3.0) 점수: %.2f%n", scoreMoores);
    }

    private double calcWithParams(String polygonPoints, List<TrackRequest.NodeDTO> nodes,
                                  double buffer, double softFactor) {
        SimilarityService svc = new SimilarityService(new ObjectMapper(), buffer, softFactor);
        return svc.calculate(polygonPoints, nodes);
    }

    private String extractPolarSort(String base64Image) throws Exception {
        byte[] imageBytes = Base64.getDecoder().decode(base64Image);
        java.awt.image.BufferedImage img = javax.imageio.ImageIO.read(new java.io.ByteArrayInputStream(imageBytes));
        int width = img.getWidth(), height = img.getHeight();

        java.util.Set<String> seen = new java.util.LinkedHashSet<>();
        List<double[]> pts = new ArrayList<>();
        for (int y = 0; y < height; y++) {
            int left = -1, right = -1;
            for (int x = 0; x < width; x++) {
                int rgb = img.getRGB(x, y); int r=(rgb>>16)&0xFF,g=(rgb>>8)&0xFF,b=rgb&0xFF;
                if ((r+g+b)/3 > 50) { if(left<0) left=x; right=x; }
            }
            if (left>=0) { addPt(seen,pts,(double)left/width,(double)y/height); if(right!=left) addPt(seen,pts,(double)right/width,(double)y/height); }
        }
        for (int x = 0; x < width; x++) {
            int top=-1,bottom=-1;
            for (int y = 0; y < height; y++) {
                int rgb=img.getRGB(x,y); int r=(rgb>>16)&0xFF,g=(rgb>>8)&0xFF,b=rgb&0xFF;
                if((r+g+b)/3>50){if(top<0)top=y;bottom=y;}
            }
            if(top>=0){addPt(seen,pts,(double)x/width,(double)top/height);if(bottom!=top)addPt(seen,pts,(double)x/width,(double)bottom/height);}
        }
        double cx=pts.stream().mapToDouble(p->p[0]).average().orElse(0.5);
        double cy=pts.stream().mapToDouble(p->p[1]).average().orElse(0.5);
        pts.sort(java.util.Comparator.comparingDouble(p->Math.atan2(p[1]-cy,p[0]-cx)));
        return new ObjectMapper().writeValueAsString(pts);
    }

    private void addPt(java.util.Set<String> seen, List<double[]> pts, double x, double y) {
        if (seen.add(String.format("%.6f:%.6f", x, y))) pts.add(new double[]{x, y});
    }
}
