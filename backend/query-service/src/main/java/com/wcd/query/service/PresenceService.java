package com.wcd.query.service;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import java.util.Set;

@Service
public class PresenceService {

    private final RedisTemplate<String, String> redisTemplate;

    public PresenceService(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public long getOnlineCount() {
        Set<String> keys = redisTemplate.keys("presence:*");
        return keys.size();
    }
}
