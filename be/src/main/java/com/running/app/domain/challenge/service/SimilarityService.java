package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class SimilarityService {

    private final ObjectMapper objectMapper;

    private static final int RESAMPLE_COUNT = 500;
    // bbox 긴 변 기준 3% — 정규화 후 단위 없는 거리
    private static final double BUFFER = 0.03;

    public Double calculate(String polygonPointsJson, List<TrackRequest.NodeDTO> userNodes) {
        try {
            double[][] challengeRaw = parsePolygon(polygonPointsJson);
            double[][] userEnu = toEnu(userNodes);

            double[][] challengeNorm = normalize(challengeRaw);
            double[][] userNorm = normalize(userEnu);

            double[][] challengeResampled = resample(challengeNorm, RESAMPLE_COUNT);
            double[][] userResampled = resample(userNorm, RESAMPLE_COUNT);

            // coverage: 사용자 경로 점들이 챌린지 폴리라인 buffer 안에 있는 비율
            double coverage = computeCoverage(userResampled, challengeResampled);
            // adherence: 챌린지 경로 점들이 사용자 폴리라인 buffer 안에 있는 비율
            double adherence = computeCoverage(challengeResampled, userResampled);

            double score = Math.min(coverage, adherence) * 100.0;
            return Math.round(score * 100.0) / 100.0;

        } catch (Exception e) {
            log.warn("유사도 계산 실패: {}", e.getMessage());
            return 0.0;
        }
    }

    // JSON [[x,y],...] → double[][]
    private double[][] parsePolygon(String json) throws Exception {
        List<List<Double>> raw = objectMapper.readValue(json, new TypeReference<>() {});
        double[][] result = new double[raw.size()][2];
        for (int i = 0; i < raw.size(); i++) {
            result[i][0] = raw.get(i).get(0);
            result[i][1] = raw.get(i).get(1);
        }
        return result;
    }

    // GPS lat/lng → ENU 로컬 평면 좌표 (단위: 미터)
    // 위도 1도 = 약 111.32km (지구 둘레/360°), 경도 1도 = 111.32km × cos(위도)
    private double[][] toEnu(List<TrackRequest.NodeDTO> nodes) {
        double lat0 = nodes.stream().mapToDouble(TrackRequest.NodeDTO::getLat).average().orElse(0);
        double lon0 = nodes.stream().mapToDouble(TrackRequest.NodeDTO::getLng).average().orElse(0);
        double cosLat = Math.cos(Math.toRadians(lat0));

        double[][] result = new double[nodes.size()][2];
        for (int i = 0; i < nodes.size(); i++) {
            TrackRequest.NodeDTO node = nodes.get(i);
            result[i][0] = (node.getLng() - lon0) * cosLat * 111320; // dE (동서)
            result[i][1] = (node.getLat() - lat0) * 111320;           // dN (남북)
        }
        return result;
    }

    // centroid → (0, 0) 이동, 종횡비 유지한 채 긴 변 = 1.0으로 스케일
    private double[][] normalize(double[][] points) {
        double cx = 0, cy = 0;
        for (double[] p : points) { cx += p[0]; cy += p[1]; }
        cx /= points.length;
        cy /= points.length;

        double minX = Double.MAX_VALUE, maxX = -Double.MAX_VALUE;
        double minY = Double.MAX_VALUE, maxY = -Double.MAX_VALUE;
        double[][] centered = new double[points.length][2];
        for (int i = 0; i < points.length; i++) {
            centered[i][0] = points[i][0] - cx;
            centered[i][1] = points[i][1] - cy;
            minX = Math.min(minX, centered[i][0]);
            maxX = Math.max(maxX, centered[i][0]);
            minY = Math.min(minY, centered[i][1]);
            maxY = Math.max(maxY, centered[i][1]);
        }

        double scale = Math.max(maxX - minX, maxY - minY);
        if (scale == 0) return centered;

        double[][] result = new double[points.length][2];
        for (int i = 0; i < points.length; i++) {
            result[i][0] = centered[i][0] / scale;
            result[i][1] = centered[i][1] / scale;
        }
        return result;
    }

    // 누적 호 길이 기준 선형 보간 → n개 등간격 점 (점 순서 유지)
    private double[][] resample(double[][] points, int n) {
        if (points.length == 0) return new double[0][2];
        if (points.length == 1) {
            double[][] r = new double[n][2];
            for (int i = 0; i < n; i++) { r[i][0] = points[0][0]; r[i][1] = points[0][1]; }
            return r;
        }

        // 누적 거리 계산
        double[] cumLen = new double[points.length];
        cumLen[0] = 0;
        for (int i = 1; i < points.length; i++) {
            double dx = points[i][0] - points[i - 1][0];
            double dy = points[i][1] - points[i - 1][1];
            cumLen[i] = cumLen[i - 1] + Math.sqrt(dx * dx + dy * dy);
        }
        double totalLen = cumLen[points.length - 1];
        if (totalLen == 0) {
            double[][] r = new double[n][2];
            for (int i = 0; i < n; i++) { r[i][0] = points[0][0]; r[i][1] = points[0][1]; }
            return r;
        }

        double step = totalLen / (n - 1);
        double[][] result = new double[n][2];
        int seg = 0;
        for (int i = 0; i < n; i++) {
            double target = i * step;
            while (seg < points.length - 2 && cumLen[seg + 1] < target) seg++;
            double segLen = cumLen[seg + 1] - cumLen[seg];
            double t = segLen == 0 ? 0 : (target - cumLen[seg]) / segLen;
            result[i][0] = points[seg][0] + t * (points[seg + 1][0] - points[seg][0]);
            result[i][1] = points[seg][1] + t * (points[seg + 1][1] - points[seg][1]);
        }
        return result;
    }

    // queryPoints 중 referencePolyline에서 BUFFER 이내인 점의 비율
    private double computeCoverage(double[][] queryPoints, double[][] referencePolyline) {
        int covered = 0;
        for (double[] q : queryPoints) {
            if (isWithinBuffer(q, referencePolyline)) covered++;
        }
        return (double) covered / queryPoints.length;
    }

    private boolean isWithinBuffer(double[] p, double[][] polyline) {
        for (int i = 0; i < polyline.length - 1; i++) {
            if (distToSegment(p, polyline[i], polyline[i + 1]) <= BUFFER) return true;
        }
        return false;
    }

    // 점 p에서 선분 [a, b]까지의 최단 거리
    private double distToSegment(double[] p, double[] a, double[] b) {
        double abx = b[0] - a[0], aby = b[1] - a[1];
        double apx = p[0] - a[0], apy = p[1] - a[1];
        double ab2 = abx * abx + aby * aby;
        double t = ab2 == 0 ? 0 : Math.max(0, Math.min(1, (apx * abx + apy * aby) / ab2));
        double dx = p[0] - (a[0] + t * abx);
        double dy = p[1] - (a[1] + t * aby);
        return Math.sqrt(dx * dx + dy * dy);
    }
}
