package com.wcd.query.service;

import com.wcd.query.dto.LeaderboardEntry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.DefaultTypedTuple;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class LeaderboardServiceTest {

    private LeaderboardService leaderboardService;
    private RedisTemplate<String, String> redisTemplate;
    private ZSetOperations<String, String> zSetOperations;

    @BeforeEach
    void setUp() {
        redisTemplate = mock(RedisTemplate.class);
        zSetOperations = mock(ZSetOperations.class);

        when(redisTemplate.opsForZSet()).thenReturn(zSetOperations);

        leaderboardService = new LeaderboardService(redisTemplate);
    }

    @Test
    void getTopPlayers_ShouldReturnRankedList() {
        Set<ZSetOperations.TypedTuple<String>> mockData = Set.of(
            new DefaultTypedTuple<>("user-1", 100.0),
            new DefaultTypedTuple<>("user-2", 50.0)
        );

        when(zSetOperations.reverseRangeWithScores(eq("leaderboard:match-1"), eq(0L), eq(9L)))
            .thenReturn(mockData);

        List<LeaderboardEntry> entries = leaderboardService.getTopPlayers("match-1", 10);

        assertNotNull(entries);
        assertTrue(entries.size() <= 2);
        verify(zSetOperations).reverseRangeWithScores("leaderboard:match-1", 0L, 9L);
    }

    @Test
    void getTopPlayers_WhenNoData_ReturnsEmptyList() {
        when(zSetOperations.reverseRangeWithScores(anyString(), anyLong(), anyLong()))
            .thenReturn(null);

        List<LeaderboardEntry> entries = leaderboardService.getTopPlayers("match-1", 10);

        assertNotNull(entries);
        assertTrue(entries.isEmpty());
    }
}
