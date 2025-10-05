package com.wcd.ingest.controller;

import com.wcd.common.events.GameActionV1;
import com.wcd.ingest.service.EventPublisher;
import io.github.bucket4j.Bucket;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class EventControllerTest {

    private EventController controller;
    private EventPublisher eventPublisher;
    private Bucket rateLimitBucket;
    private final String validApiKey = "test-api-key";

    @BeforeEach
    void setUp() {
        eventPublisher = mock(EventPublisher.class);
        rateLimitBucket = mock(Bucket.class);
        SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();

        controller = new EventController(
            eventPublisher,
            rateLimitBucket,
            validApiKey,
            meterRegistry
        );
    }

    @Test
    void heartbeat_WithValidApiKey_ReturnsAccepted() {
        when(rateLimitBucket.tryConsume(1)).thenReturn(true);

        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setRegion("EU");
        event.setMatchId("match-1");

        ResponseEntity<?> response = controller.heartbeat(validApiKey, event);

        assertEquals(HttpStatus.ACCEPTED, response.getStatusCode());
        verify(eventPublisher, times(1)).publish(any(GameActionV1.class));
    }

    @Test
    void heartbeat_WithInvalidApiKey_ReturnsUnauthorized() {
        GameActionV1 event = new GameActionV1();

        ResponseEntity<?> response = controller.heartbeat("wrong-key", event);

        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        verify(eventPublisher, never()).publish(any());
    }

    @Test
    void drink_WithValidApiKey_ReturnsAccepted() {
        when(rateLimitBucket.tryConsume(1)).thenReturn(true);

        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setRegion("EU");
        event.setMatchId("match-1");
        event.setAmount(2);

        ResponseEntity<?> response = controller.drink(validApiKey, event);

        assertEquals(HttpStatus.ACCEPTED, response.getStatusCode());
        verify(eventPublisher, times(1)).publish(any(GameActionV1.class));
    }

    @Test
    void drink_WhenRateLimitExceeded_ReturnsTooManyRequests() {
        when(rateLimitBucket.tryConsume(1)).thenReturn(false);

        GameActionV1 event = new GameActionV1();

        ResponseEntity<?> response = controller.drink(validApiKey, event);

        assertEquals(HttpStatus.TOO_MANY_REQUESTS, response.getStatusCode());
        verify(eventPublisher, never()).publish(any());
    }
}
