package com.wcd.projector;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.kafka.core.ConsumerFactory;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

@SpringBootTest
@org.springframework.test.context.TestPropertySource(properties = {
    "spring.kafka.bootstrap-servers=localhost:9092",
    "spring.kafka.consumer.group-id=test-group",
    "wcd.topic.game-actions=test-topic",
    "wcd.projection.presence-ttl-seconds=30"
})
class ProjectorServiceApplicationTest {

    @MockBean
    private RedisTemplate<String, String> redisTemplate;

    @MockBean
    private ConsumerFactory<String, Object> consumerFactory;

    @Test
    void contextLoads() {
        assertDoesNotThrow(() -> {});
    }
}
