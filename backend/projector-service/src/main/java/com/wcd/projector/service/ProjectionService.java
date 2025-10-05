package com.wcd.projector.service;

import com.wcd.common.events.GameActionV1;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.TimeUnit;

@Service
public class ProjectionService {

    private static final Logger logger = LoggerFactory.getLogger(ProjectionService.class);
    private static final DateTimeFormatter MINUTE_FORMATTER = DateTimeFormatter.ofPattern("yyyyMMddHHmm")
        .withZone(ZoneId.of("UTC"));

    private final RedisTemplate<String, String> redisTemplate;
    private final int presenceTtlSeconds;

    public ProjectionService(
        RedisTemplate<String, String> redisTemplate,
        @Value("${wcd.redis.presence-ttl-seconds}") int presenceTtlSeconds
    ) {
        this.redisTemplate = redisTemplate;
        this.presenceTtlSeconds = presenceTtlSeconds;
    }

    public void updatePresence(GameActionV1 event) {
        String key = "presence:" + event.getUserId();
        redisTemplate.opsForValue().set(key, event.getRegion(), presenceTtlSeconds, TimeUnit.SECONDS);
        logger.debug("Updated presence for user {}: region={}", event.getUserId(), event.getRegion());
    }

    public void updateLeaderboard(GameActionV1 event) {
        String key = "leaderboard:" + event.getMatchId();
        redisTemplate.opsForZSet().incrementScore(key, event.getUserId(), event.getAmount());
        logger.debug("Updated leaderboard for match {}: user={}, amount={}",
            event.getMatchId(), event.getUserId(), event.getAmount());
    }

    public void updateUniques(GameActionV1 event) {
        Instant timestamp = Instant.ofEpochMilli(event.getTimestamp());
        String minuteKey = MINUTE_FORMATTER.format(timestamp);
        String key = "uniques:" + minuteKey;

        redisTemplate.opsForHyperLogLog().add(key, event.getUserId());
        redisTemplate.expire(key, 1, TimeUnit.HOURS);
        logger.debug("Updated uniques for minute {}: user={}", minuteKey, event.getUserId());
    }
}
