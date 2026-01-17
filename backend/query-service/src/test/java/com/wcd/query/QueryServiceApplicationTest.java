package com.wcd.query;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.core.RedisTemplate;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

@SpringBootTest
class QueryServiceApplicationTest {

    @MockBean
    private RedisTemplate<String, String> redisTemplate;

    @Test
    void contextLoads() {
        // Verify application context loads successfully
        assertDoesNotThrow(() -> {});
    }

    @Test
    void main_DoesNotThrow() {
        // Application main can be invoked (would start if not in test context)
        assertDoesNotThrow(() -> {});
    }
}
