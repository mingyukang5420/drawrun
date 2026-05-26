package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import javax.imageio.ImageIO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
@RequiredArgsConstructor
public class ChallengeOutlineExtractService {

    private final ObjectMapper objectMapper;

    // 8방향 시계 순서: E → SE → S → SW → W → NW → N → NE
    private static final int[] DX = { 1,  1,  0, -1, -1, -1,  0,  1};
    private static final int[] DY = { 0,  1,  1,  1,  0, -1, -1, -1};

    // PNG base64 → 정규화 2D 좌표 JSON ([[x, y], ...], x/y ∈ [0, 1])
    // Moore's Neighborhood Algorithm으로 경계 픽셀을 실제 윤곽 순서대로 수집한다.
    // 극좌표 정렬과 달리 오목(concave) 형상에서도 올바른 세그먼트 순서를 보장한다.
    public String extract(String base64Image) {
        try {
            byte[] imageBytes = Base64.getDecoder().decode(base64Image);
            BufferedImage img = ImageIO.read(new ByteArrayInputStream(imageBytes));

            if (img == null) {
                log.warn("이미지 디코딩 실패: BufferedImage가 null");
                return null;
            }

            int W = img.getWidth();
            int H = img.getHeight();

            // 1. 첫 번째 경계 픽셀 탐색 (top→bottom, left→right)
            int startX = -1, startY = -1;
            outer:
            for (int y = 0; y < H; y++) {
                for (int x = 0; x < W; x++) {
                    if (!isBlack(img, x, y)) {
                        startX = x;
                        startY = y;
                        break outer;
                    }
                }
            }

            if (startX < 0) {
                log.warn("윤곽선 픽셀 없음: 이미지가 완전히 검정이거나 임계값 설정 문제");
                return null;
            }

            // 2. Moore's Neighborhood 순회 — 경계를 따라 시계 방향으로 추적
            // Jacob's Stopping Criterion: 두 번째 픽셀 B를 최초 진입과 동일한 방향으로
            // 재진입할 때 종료. start 복귀 기반 종료는 두꺼운 윤곽선에서 대각선 지름길로
            // 3픽셀 만에 조기 종료되고, start 복귀 방향 기반 종료는 두꺼운 윤곽선에서
            // 마지막 진입 방향이 달라 maxIter까지 무한 순회하는 버그가 있다.
            List<double[]> contour = new ArrayList<>();
            int cx = startX, cy = startY;
            // 첫 픽셀은 left→right 스캔으로 발견됐으므로 서쪽(W=4)에서 진입, E(0) 방향으로 이동
            int entryDir = 0;
            int bx = -1, by = -1; // 두 번째 픽셀 B (start에서 처음 이동한 픽셀)
            int d0 = -1;          // B로 최초 진입한 방향
            boolean leftB = false; // B를 벗어난 적 있는지 (첫 방문 이후 재진입 구분용)
            int maxIter = W * H * 4; // 무한루프 방지 상한

            for (int iter = 0; iter < maxIter; iter++) {
                contour.add(new double[]{(double) cx / W, (double) cy / H});
                // 역진입 방향부터 시계 방향으로 다음 경계 픽셀 탐색
                int backDir = (entryDir + 4) % 8;
                boolean found = false;
                for (int i = 1; i <= 8; i++) {
                    int dir = (backDir + i) % 8;
                    int nx = cx + DX[dir];
                    int ny = cy + DY[dir];
                    if (nx >= 0 && nx < W && ny >= 0 && ny < H && !isBlack(img, nx, ny)) {
                        entryDir = dir;
                        cx = nx;
                        cy = ny;
                        found = true;
                        break;
                    }
                }
                if (!found) break; // 고립된 단일 픽셀
                if (bx < 0) { bx = cx; by = cy; d0 = entryDir; } // 두 번째 픽셀 기록
                if (!leftB && (cx != bx || cy != by)) leftB = true;
                // Jacob's criterion: B에 최초와 동일한 방향으로 재진입 → 윤곽 한 바퀴 완료
                if (leftB && cx == bx && cy == by && entryDir == d0) break;
            }

            if (contour.isEmpty()) {
                return null;
            }

            return objectMapper.writeValueAsString(contour);
        } catch (Exception e) {
            log.warn("윤곽선 추출 실패: {}", e.getMessage());
            return null;
        }
    }

    // 최대 채널 값 ≤ 30 이면 검정으로 판단
    // avg 50 기준은 GPT가 생성하는 중간 밝기 녹색(예: (0,120,0), avg=40)을 검정으로 분류하는 버그가 있어 max 채널로 교체
    private boolean isBlack(BufferedImage img, int x, int y) {
        int rgb = img.getRGB(x, y);
        int r = (rgb >> 16) & 0xFF;
        int g = (rgb >> 8) & 0xFF;
        int b = rgb & 0xFF;
        return Math.max(r, Math.max(g, b)) <= 30;
    }
}
