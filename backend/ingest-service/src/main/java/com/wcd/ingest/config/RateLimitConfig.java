package com.wcd.ingest.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

@Configuration
public class RateLimitConfig {

    @Value("${wcd.rate-limit.capacity:100}")
    private long capacity;

    @Value("${wcd.rate-limit.refill-tokens:100}")
    private long refillTokens;

    @Value("${wcd.rate-limit.refill-duration-seconds:1}")
    private long refillDurationSeconds;

    @Bean
    public Bucket rateLimitBucket() {
        Bandwidth limit = Bandwidth.classic(
            capacity,
            Refill.intervally(refillTokens, Duration.ofSeconds(refillDurationSeconds))
        );
        return Bucket.builder()
            .addLimit(limit)
            .build();
    }
}
