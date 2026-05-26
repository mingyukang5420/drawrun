package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;

class ChallengeOutlineExtractServiceTest {

    private ChallengeOutlineExtractService service;

    @BeforeEach
    void setUp() {
        service = new ChallengeOutlineExtractService(new ObjectMapper());
    }

    // (0,120,0) 중간 녹색 — avg=40으로 수정 전 isBlack 기준(avg≤50)에서 검정 처리됐던 색상
    // 수정 후 max=120>30으로 비검정 판정 → 윤곽선 정상 추출 검증
    @Test
    void extract_midGreenOutline_returnsMoreThan3Points() throws Exception {
        BufferedImage img = new BufferedImage(100, 100, BufferedImage.TYPE_INT_RGB);
        int midGreen = new java.awt.Color(0, 120, 0).getRGB();
        for (int x = 10; x <= 90; x++) {
            img.setRGB(x, 10, midGreen);
            img.setRGB(x, 90, midGreen);
        }
        for (int y = 10; y <= 90; y++) {
            img.setRGB(10, y, midGreen);
            img.setRGB(90, y, midGreen);
        }

        String result = service.extract(toBase64(img));

        assertThat(result).isNotNull();
        double[][] points = new ObjectMapper().readValue(result, double[][].class);
        assertThat(points.length).isGreaterThan(10);
    }

    @Test
    void extract_pureBlackImage_returnsNull() throws Exception {
        BufferedImage img = new BufferedImage(50, 50, BufferedImage.TYPE_INT_RGB);
        assertThat(service.extract(toBase64(img))).isNull();
    }

    private String toBase64(BufferedImage img) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        ImageIO.write(img, "png", baos);
        return Base64.getEncoder().encodeToString(baos.toByteArray());
    }
}
