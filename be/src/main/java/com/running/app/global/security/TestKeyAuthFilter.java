package com.running.app.global.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class TestKeyAuthFilter extends OncePerRequestFilter {

    private final String testKey;

    public TestKeyAuthFilter(@Value("${TEST_KEY}") String testKey) {
        this.testKey = testKey;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {
        String key = request.getHeader("X-Test-Key");
        if (key == null || !key.equals(testKey)) {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid test key");
            return;
        }
        filterChain.doFilter(request, response);
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !request.getRequestURI().startsWith("/v1/call/test/");
    }
}
