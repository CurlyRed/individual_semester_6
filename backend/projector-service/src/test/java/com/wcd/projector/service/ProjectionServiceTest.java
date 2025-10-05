package com.wcd.projector.service;

import com.wcd.common.events.GameActionV1;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.data.redis.core.HyperLogLogOperations;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ProjectionServiceTest {

    private ProjectionService projectionService;
    private RedisTemplate<String, String> redisTemplate;
    private ValueOperations<String, String> valueOperations;
    private ZSetOperations<String, String> zSetOperations;
    private HyperLogLogOperations<String, String> hllOperations;

    @BeforeEach
    void setUp() {
        redisTemplate = mock(RedisTemplate.class);
        valueOperations = mock(ValueOperations.class);
        zSetOperations = mock(ZSetOperations.class);
        hllOperations = mock(HyperLogLogOperations.class);

        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(redisTemplate.opsForZSet()).thenReturn(zSetOperations);
        when(redisTemplate.opsForHyperLogLog()).thenReturn(hllOperations);

        projectionService = new ProjectionService(redisTemplate, 30);
    }

    @Test
    void updatePresence_ShouldSetRedisKeyWithTTL() {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setRegion("EU");

        projectionService.updatePresence(event);

        verify(valueOperations).set(eq("presence:user-1"), eq("EU"), eq(30L), any());
    }

    @Test
    void updateLeaderboard_ShouldIncrementScore() {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setMatchId("match-1");
        event.setAmount(3);

        projectionService.updateLeaderboard(event);

        verify(zSetOperations).incrementScore("leaderboard:match-1", "user-1", 3);
    }

    @Test
    void updateUniques_ShouldAddToHyperLogLog() {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setTimestamp(System.currentTimeMillis());

        projectionService.updateUniques(event);

        verify(hllOperations).add(anyString(), eq("user-1"));
        verify(redisTemplate).expire(anyString(), anyLong(), any());
    }
}
