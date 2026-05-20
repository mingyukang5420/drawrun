package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.running.app.domain.track.dto.TrackRequest;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class SimilarityService {

    private final ObjectMapper objectMapper;
    private final double BUFFER;
    private final double SOFT_FACTOR;

    private static final int RESAMPLE_COUNT = 200;

    // 고정 물리 버퍼 목표값 (미터) — GPS 경로 bbox 대비 비율로 자동 정규화됨
    // 10m: 강아지 경로(~390m bbox) → 0.026, 사각형(~200m bbox) → 0.049
    private static final double TARGET_BUFFER_METER = 10.0;
    // 버퍼 상한 (bbox 대비 최대 5%) — 소형 경로가 과도하게 관대해지는 것을 방지
    private static final double MAX_BUFFER = 0.05;

    public SimilarityService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
        this.BUFFER = 0;
        this.SOFT_FACTOR = 2.0;
    }

    // coarse 탐색 간격 (도)
    private static final int COARSE_STEP_DEG = 10;
    // fine 탐색 범위 (최적 각도 ±FINE_RANGE_DEG, 1° 간격)
    private static final int FINE_RANGE_DEG = 12;

    // 서울 위도(37.5°)에서 경도 1°와 위도 1°의 거리 비율: cos(37.5°) ≈ 0.7934
    private static final double SEOUL_LAT_DEG = 37.5;
    private static final double LNG_LAT_RATIO = Math.cos(Math.toRadians(SEOUL_LAT_DEG));

    public Double calculate(String polygonPointsJson, List<TrackRequest.NodeDTO> userNodes) {
        try {
            double[][] challengeRaw = parsePolygon(polygonPointsJson);
            double[][] userRaw = toPlane(userNodes);

            // GPS 경로의 물리 bbox(미터)로 버퍼 정규화
            // BUFFER=0이면 동적 계산, 테스트 등에서 BUFFER>0이면 고정값 유지
            double effectiveBuffer = (BUFFER > 0)
                ? BUFFER
                : computeDynamicBuffer(userRaw);

            // resample 먼저 → 등간격 점 기준 centroid 계산 → normalize
            double[][] challengeResampled = normalize(resample(challengeRaw, RESAMPLE_COUNT));
            double[][] userResampled      = normalize(resample(userRaw,      RESAMPLE_COUNT));

            // 정방향 + 경로 방향 반전(mirror) 중 더 나은 점수 채택
            double score = Math.max(
                bestScore(challengeResampled, userResampled, effectiveBuffer),
                bestScore(challengeResampled, mirrorPoints(userResampled), effectiveBuffer)
            );
            return Math.round(score * 100.0) / 100.0;

        } catch (Exception e) {
            log.warn("유사도 계산 실패: {}", e.getMessage());
            return 0.0;
        }
    }

    // GPS 경로의 toPlane() 출력(도 단위) 기준 물리 bbox 계산 → TARGET_BUFFER_METER 정규화
    // min(TARGET/bbox, MAX_BUFFER): 소형 경로의 버퍼 과대 방지, 대형 경로만 압축
    private double computeDynamicBuffer(double[][] userRaw) {
        double minX = Double.MAX_VALUE, maxX = -Double.MAX_VALUE;
        double minY = Double.MAX_VALUE, maxY = -Double.MAX_VALUE;
        for (double[] p : userRaw) {
            if (p[0] < minX) minX = p[0]; if (p[0] > maxX) maxX = p[0];
            if (p[1] < minY) minY = p[1]; if (p[1] > maxY) maxY = p[1];
        }
        double bboxDeg = Math.max(maxX - minX, maxY - minY);
        double bboxM   = bboxDeg * 111320.0;
        return bboxM > 0 ? Math.min(TARGET_BUFFER_METER / bboxM, MAX_BUFFER) : MAX_BUFFER;
    }

    // 2단계 회전 탐색: coarse(10°) → fine(±12°, 1°) 로 최고 점수 반환
    private double bestScore(double[][] challenge, double[][] user, double buffer) {
        double bestAngleDeg = 0;
        double bestRaw = -1;

        // Stage 1: 0°~350°, 10° 간격
        for (int deg = 0; deg < 360; deg += COARSE_STEP_DEG) {
            double raw = scoreAtAngle(challenge, user, deg, buffer);
            if (raw > bestRaw) {
                bestRaw = raw;
                bestAngleDeg = deg;
            }
        }

        // Stage 2: 최적 주변 ±FINE_RANGE_DEG, 1° 간격
        for (int d = -FINE_RANGE_DEG; d <= FINE_RANGE_DEG; d++) {
            double deg = bestAngleDeg + d;
            double raw = scoreAtAngle(challenge, user, deg, buffer);
            if (raw > bestRaw) {
                bestRaw = raw;
            }
        }

        return bestRaw * 100.0;
    }

    private double scoreAtAngle(double[][] challenge, double[][] user, double angleDeg, double buffer) {
        double[][] rotated = rotatePoints(user, Math.toRadians(angleDeg));
        double coverage  = computeCoverage(rotated, challenge, buffer);
        double adherence = computeCoverage(challenge, rotated, buffer);
        return (coverage + adherence) / 2.0;
    }

    // 점들을 원점 기준으로 angleRad 만큼 회전
    private double[][] rotatePoints(double[][] pts, double angleRad) {
        double cos = Math.cos(angleRad);
        double sin = Math.sin(angleRad);
        double[][] result = new double[pts.length][2];
        for (int i = 0; i < pts.length; i++) {
            result[i][0] = pts[i][0] * cos - pts[i][1] * sin;
            result[i][1] = pts[i][0] * sin + pts[i][1] * cos;
        }
        return result;
    }

    // Y좌표 반전 — 경로를 반대 방향(시계↔반시계)으로 달린 경우 처리
    private double[][] mirrorPoints(double[][] pts) {
        double[][] result = new double[pts.length][2];
        for (int i = 0; i < pts.length; i++) {
            result[i][0] =  pts[i][0];
            result[i][1] = -pts[i][1];
        }
        return result;
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

    // GPS lat/lng 차이값을 직접 평면 좌표로 변환 (단위: 도)
    // 111320 미터 변환 생략 — normalize()에서 약분되므로 형태에 무관
    // 경도 차이에 LNG_LAT_RATIO 적용 → 서울 위도에서 시각적 종횡비 보정
    private double[][] toPlane(List<TrackRequest.NodeDTO> nodes) {
        double lat0 = nodes.stream().mapToDouble(TrackRequest.NodeDTO::getLat).average().orElse(0);
        double lng0 = nodes.stream().mapToDouble(TrackRequest.NodeDTO::getLng).average().orElse(0);

        double[][] result = new double[nodes.size()][2];
        for (int i = 0; i < nodes.size(); i++) {
            TrackRequest.NodeDTO node = nodes.get(i);
            result[i][0] = (node.getLng() - lng0) * LNG_LAT_RATIO; // x: 경도 차이 × 비율
            result[i][1] = (node.getLat() - lat0);                   // y: 위도 차이
        }
        return result;
    }

    // bbox 중심 → (0,0) 이동, 종횡비 유지한 채 긴 변 = 1.0으로 스케일
    // centroid 대신 bbox 중심 사용: 개방 경로(일부 변 누락)에서 centroid는 존재하는 점 쪽으로
    // 치우치지만, bbox 중심은 경로가 차지하는 공간 범위의 중심이라 형상 정렬에 더 안정적
    private double[][] normalize(double[][] points) {
        double minX = Double.MAX_VALUE, maxX = -Double.MAX_VALUE;
        double minY = Double.MAX_VALUE, maxY = -Double.MAX_VALUE;
        for (double[] p : points) {
            minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]);
            minY = Math.min(minY, p[1]); maxY = Math.max(maxY, p[1]);
        }
        double cx = (minX + maxX) / 2;
        double cy = (minY + maxY) / 2;
        double scale = Math.max(maxX - minX, maxY - minY);
        if (scale == 0) return points;

        double[][] result = new double[points.length][2];
        for (int i = 0; i < points.length; i++) {
            result[i][0] = (points[i][0] - cx) / scale;
            result[i][1] = (points[i][1] - cy) / scale;
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

    // queryPoints 각 점의 referencePolyline 근접 점수 평균
    // 0~buffer: 1.0 (완전 점수), buffer~buffer×SOFT_FACTOR: 코사인 감쇠, 이상: 0
    private double computeCoverage(double[][] queryPoints, double[][] referencePolyline, double buffer) {
        double total = 0;
        for (double[] q : queryPoints) {
            total += pointScore(q, referencePolyline, buffer);
        }
        return total / queryPoints.length;
    }

    private double pointScore(double[] p, double[][] polyline, double buffer) {
        double minDist = Double.MAX_VALUE;
        for (int i = 0; i < polyline.length; i++) {
            double d = distToSegment(p, polyline[i], polyline[(i + 1) % polyline.length]);
            if (d <= buffer) return 1.0;   // 조기 종료
            if (d < minDist) minDist = d;
        }
        double softLimit = buffer * SOFT_FACTOR;
        if (minDist >= softLimit) return 0.0;
        // 코사인 감쇠: buffer~softLimit 구간에서 1.0→0.0 부드럽게 수렴
        double t = (minDist - buffer) / (softLimit - buffer); // 0~1
        return 0.5 * (1.0 + Math.cos(Math.PI * t));
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
