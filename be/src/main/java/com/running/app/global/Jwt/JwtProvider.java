package com.running.app.global.Jwt;

import javax.crypto.SecretKey;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class JwtProvider {

    private final SecretKey key;
}
