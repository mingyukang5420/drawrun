package com.running.app.domain.challenge.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;

class SimilarityServiceTest {

    private SimilarityService similarityService;

    @BeforeEach
    void setUp() {
        similarityService = new SimilarityService(new ObjectMapper());
    }
}
