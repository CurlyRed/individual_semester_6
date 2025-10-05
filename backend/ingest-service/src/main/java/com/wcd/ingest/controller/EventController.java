package com.wcd.ingest.controller;

import com.wcd.common.events.GameActionV1;
import com.wcd.ingest.service.EventPublisher;
import io.github.bucket4j.Bucket;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/events")
public class EventController {

    private final EventPublisher eventPublisher;
    private final Bucket rateLimitBucket;
    private final String apiKey;
    private final Counter heartbeatCounter;
    private final Counter drinkCounter;
    private final Counter rejectedCounter;

    public EventController(
        EventPublisher eventPublisher,
        Bucket rateLimitBucket,
        @Value("${wcd.api-key}") String apiKey,
        MeterRegistry meterRegistry
    ) {
        this.eventPublisher = eventPublisher;
        this.rateLimitBucket = rateLimitBucket;
        this.apiKey = apiKey;
        this.heartbeatCounter = Counter.builder("wcd.events.heartbeat")
            .description("Total heartbeat events received")
            .register(meterRegistry);
        this.drinkCounter = Counter.builder("wcd.events.drink")
            .description("Total drink events received")
            .register(meterRegistry);
        this.rejectedCounter = Counter.builder("wcd.events.rejected")
            .description("Total events rejected")
            .register(meterRegistry);
    }

    @PostMapping("/heartbeat")
    public ResponseEntity<?> heartbeat(
        @RequestHeader("X-API-KEY") String providedApiKey,
        @RequestBody GameActionV1 event
    ) {
        if (!apiKey.equals(providedApiKey)) {
            rejectedCounter.increment();
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Invalid API key"));
        }

        if (!rateLimitBucket.tryConsume(1)) {
            rejectedCounter.increment();
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of("error", "Rate limit exceeded"));
        }

        event.setAction("HEARTBEAT");
        event.setTimestamp(System.currentTimeMillis());
        eventPublisher.publish(event);
        heartbeatCounter.increment();

        return ResponseEntity.accepted().body(Map.of("status", "accepted"));
    }

    @PostMapping("/drink")
    public ResponseEntity<?> drink(
        @RequestHeader("X-API-KEY") String providedApiKey,
        @RequestBody GameActionV1 event
    ) {
        if (!apiKey.equals(providedApiKey)) {
            rejectedCounter.increment();
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Invalid API key"));
        }

        if (!rateLimitBucket.tryConsume(1)) {
            rejectedCounter.increment();
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of("error", "Rate limit exceeded"));
        }

        event.setAction("DRINK");
        event.setTimestamp(System.currentTimeMillis());
        eventPublisher.publish(event);
        drinkCounter.increment();

        return ResponseEntity.accepted().body(Map.of("status", "accepted"));
    }
}
