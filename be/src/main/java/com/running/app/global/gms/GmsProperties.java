package com.running.app.global.gms;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Getter
@Setter
@ConfigurationProperties(prefix = "gms")
public class GmsProperties {

    private String baseUrl;
    private String apiKey;
    private String analysisModel;
    private String imageModel;
    private String imageSize;
    private Integer imageCount;
}
