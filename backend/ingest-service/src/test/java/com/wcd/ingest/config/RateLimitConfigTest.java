package com.wcd.ingest.config;

import io.github.bucket4j.Bucket;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@TestPropertySource(properties = {
    "wcd.rate-limit.capacity=10",
    "wcd.rate-limit.refill-tokens=10",
    "wcd.rate-limit.refill-duration-seconds=1",
    "wcd.api-key=test-key",
    "wcd.topic.game-actions=test-topic",
    "spring.kafka.bootstrap-servers=localhost:9092"
})
class RateLimitConfigTest {

    @Autowired
    private Bucket rateLimitBucket;

    @Test
    void rateLimitBucket_IsCreated() {
        assertNotNull(rateLimitBucket);
    }

    @Test
    void rateLimitBucket_AllowsRequestsWithinLimit() {
        // Given capacity of 10
        // All 10 requests should succeed
        for (int i = 0; i < 10; i++) {
            assertTrue(rateLimitBucket.tryConsume(1), "Request " + i + " should be allowed");
        }
    }

    @Test
    void rateLimitBucket_DeniesRequestsOverLimit() {
        // Create a new bucket for this test to avoid state from other tests
        RateLimitConfig config = new RateLimitConfig();
        // Use reflection or create a test-specific config
        Bucket testBucket = Bucket.builder()
            .addLimit(io.github.bucket4j.Bandwidth.classic(
                5,
                io.github.bucket4j.Refill.intervally(5, java.time.Duration.ofSeconds(10))
            ))
            .build();

        // Consume all tokens
        for (int i = 0; i < 5; i++) {
            assertTrue(testBucket.tryConsume(1));
        }

        // Next request should fail
        assertFalse(testBucket.tryConsume(1));
    }

    @Test
    void rateLimitBucket_RefillsOverTime() throws InterruptedException {
        Bucket testBucket = Bucket.builder()
            .addLimit(io.github.bucket4j.Bandwidth.classic(
                2,
                io.github.bucket4j.Refill.intervally(2, java.time.Duration.ofMillis(100))
            ))
            .build();

        // Consume all tokens
        assertTrue(testBucket.tryConsume(2));
        assertFalse(testBucket.tryConsume(1));

        // Wait for refill
        Thread.sleep(150);

        // Should have tokens again
        assertTrue(testBucket.tryConsume(1));
    }

    @Test
    void rateLimitBucket_ConsumeMultipleTokens() {
        Bucket testBucket = Bucket.builder()
            .addLimit(io.github.bucket4j.Bandwidth.classic(
                10,
                io.github.bucket4j.Refill.intervally(10, java.time.Duration.ofSeconds(1))
            ))
            .build();

        // Consume 5 tokens at once
        assertTrue(testBucket.tryConsume(5));
        // Consume 5 more
        assertTrue(testBucket.tryConsume(5));
        // No more tokens
        assertFalse(testBucket.tryConsume(1));
    }

    @Test
    void rateLimitBucket_CannotConsumeMoreThanCapacity() {
        Bucket testBucket = Bucket.builder()
            .addLimit(io.github.bucket4j.Bandwidth.classic(
                5,
                io.github.bucket4j.Refill.intervally(5, java.time.Duration.ofSeconds(1))
            ))
            .build();

        // Cannot consume more than capacity at once
        assertFalse(testBucket.tryConsume(10));
        // But capacity is still available
        assertTrue(testBucket.tryConsume(5));
    }
}
