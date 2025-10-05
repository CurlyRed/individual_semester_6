package com.wcd.query.service;

import com.wcd.query.dto.LeaderboardEntry;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ZSetOperations;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Service
public class LeaderboardService {

    private final RedisTemplate<String, String> redisTemplate;

    public LeaderboardService(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public List<LeaderboardEntry> getTopPlayers(String matchId, int limit) {
        String key = "leaderboard:" + matchId;
        Set<ZSetOperations.TypedTuple<String>> topScores =
            redisTemplate.opsForZSet().reverseRangeWithScores(key, 0, limit - 1);

        List<LeaderboardEntry> entries = new ArrayList<>();
        if (topScores != null) {
            int rank = 1;
            for (ZSetOperations.TypedTuple<String> tuple : topScores) {
                LeaderboardEntry entry = new LeaderboardEntry(
                    tuple.getValue(),
                    tuple.getScore() != null ? tuple.getScore() : 0.0,
                    rank++
                );
                entries.add(entry);
            }
        }

        return entries;
    }
}
