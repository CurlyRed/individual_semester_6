package com.wcd.ingest.service;

import com.wcd.common.events.GameActionV1;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

@Service
public class EventPublisher {

    private static final Logger logger = LoggerFactory.getLogger(EventPublisher.class);

    private final KafkaTemplate<String, GameActionV1> kafkaTemplate;
    private final String topicName;

    public EventPublisher(
        KafkaTemplate<String, GameActionV1> kafkaTemplate,
        @Value("${wcd.topic.game-actions}") String topicName
    ) {
        this.kafkaTemplate = kafkaTemplate;
        this.topicName = topicName;
    }

    public void publish(GameActionV1 event) {
        String key = event.getUserId();
        kafkaTemplate.send(topicName, key, event)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    logger.error("Failed to publish event: {}", event, ex);
                } else {
                    logger.debug("Published event: {} to partition {}", event, result.getRecordMetadata().partition());
                }
            });
    }
}
