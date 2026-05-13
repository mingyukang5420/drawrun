package com.running.app.global.gms.dto;

import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
public class GmsImageGenerationRequest {

    private String model;
    private String prompt;
    private Integer n;
    private String size;
}
