package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import javax.imageio.ImageIO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChallengeOutlineExtractService {

    private final ObjectMapper objectMapper;

    // PNG base64 → 정규화 2D 좌표 JSON ([[x, y], ...], x/y ∈ [0, 1])
    // 외곽 경계 픽셀(행별 좌측/우측 끝, 열별 상단/하단 끝)을 수집하고
    // centroid 기준 극각(polar angle)으로 정렬하여 폴리곤 순서를 보존한다.
    public String extract(String base64Image) {
        try {
            byte[] imageBytes = Base64.getDecoder().decode(base64Image);
            BufferedImage img = ImageIO.read(new ByteArrayInputStream(imageBytes));

            if (img == null) {
                log.warn("이미지 디코딩 실패: BufferedImage가 null");
                return null;
            }

            int width = img.getWidth();
            int height = img.getHeight();

            Set<String> seen = new LinkedHashSet<>();
            List<double[]> edgePoints = new ArrayList<>();

            // 행 스캔: 각 행에서 비-검정 픽셀의 좌측 끝과 우측 끝
            for (int y = 0; y < height; y++) {
                int left = -1, right = -1;
                for (int x = 0; x < width; x++) {
                    if (!isBlack(img, x, y)) {
                        if (left < 0) left = x;
                        right = x;
                    }
                }
                if (left >= 0) {
                    addEdgePoint(seen, edgePoints, (double) left / width, (double) y / height);
                    if (right != left) {
                        addEdgePoint(seen, edgePoints, (double) right / width, (double) y / height);
                    }
                }
            }

            // 열 스캔: 각 열에서 비-검정 픽셀의 상단 끝과 하단 끝
            for (int x = 0; x < width; x++) {
                int top = -1, bottom = -1;
                for (int y = 0; y < height; y++) {
                    if (!isBlack(img, x, y)) {
                        if (top < 0) top = y;
                        bottom = y;
                    }
                }
                if (top >= 0) {
                    addEdgePoint(seen, edgePoints, (double) x / width, (double) top / height);
                    if (bottom != top) {
                        addEdgePoint(seen, edgePoints, (double) x / width, (double) bottom / height);
                    }
                }
            }

            if (edgePoints.isEmpty()) {
                log.warn("윤곽선 픽셀 없음: 이미지가 완전히 검정이거나 임계값 설정 문제");
                return null;
            }

            // centroid 기준 극각 정렬 → 폴리곤 경계 순서 보존
            double cx = edgePoints.stream().mapToDouble(p -> p[0]).average().orElse(0.5);
            double cy = edgePoints.stream().mapToDouble(p -> p[1]).average().orElse(0.5);
            edgePoints.sort(Comparator.comparingDouble(p -> Math.atan2(p[1] - cy, p[0] - cx)));

            return objectMapper.writeValueAsString(edgePoints);
        } catch (Exception e) {
            log.warn("윤곽선 추출 실패: {}", e.getMessage());
            return null;
        }
    }

    private void addEdgePoint(Set<String> seen, List<double[]> points, double nx, double ny) {
        String key = String.format("%.6f:%.6f", nx, ny);
        if (seen.add(key)) {
            points.add(new double[]{nx, ny});
        }
    }

    // 픽셀 밝기(R+G+B 평균) ≤ 50 이면 검정으로 판단
    private boolean isBlack(BufferedImage img, int x, int y) {
        int rgb = img.getRGB(x, y);
        int r = (rgb >> 16) & 0xFF;
        int g = (rgb >> 8) & 0xFF;
        int b = rgb & 0xFF;
        return (r + g + b) / 3 <= 50;
    }
}
