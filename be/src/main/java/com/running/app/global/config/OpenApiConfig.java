package com.running.app.global.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    private static final String JWT_SCHEME_NAME = "JWT";
    private static final String TEST_KEY_SCHEME_NAME = "X-Test-Key";

    @Bean
    public OpenAPI openAPI() {
        return new OpenAPI()
                .servers(List.of(new Server().url("/api")))
                .components(new Components()
                        .addSecuritySchemes(JWT_SCHEME_NAME, new SecurityScheme()
                                .name(JWT_SCHEME_NAME)
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT"))
                        .addSecuritySchemes(TEST_KEY_SCHEME_NAME, new SecurityScheme()
                                .name(TEST_KEY_SCHEME_NAME)
                                .type(SecurityScheme.Type.APIKEY)
                                .in(SecurityScheme.In.HEADER)))
                .addSecurityItem(new SecurityRequirement()
                        .addList(JWT_SCHEME_NAME));
    }
}