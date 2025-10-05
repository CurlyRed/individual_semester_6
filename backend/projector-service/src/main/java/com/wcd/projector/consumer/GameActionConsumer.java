package com.wcd.projector.consumer;

import com.wcd.common.events.GameActionV1;
import com.wcd.projector.service.ProjectionService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

@Component
public class GameActionConsumer {

    private static final Logger logger = LoggerFactory.getLogger(GameActionConsumer.class);

    private final ProjectionService projectionService;
    private final Counter heartbeatCounter;
    private final Counter drinkCounter;

    public GameActionConsumer(ProjectionService projectionService, MeterRegistry meterRegistry) {
        this.projectionService = projectionService;
        this.heartbeatCounter = Counter.builder("wcd.projector.heartbeat")
            .description("Total heartbeat events processed")
            .register(meterRegistry);
        this.drinkCounter = Counter.builder("wcd.projector.drink")
            .description("Total drink events processed")
            .register(meterRegistry);
    }

    @KafkaListener(topics = "${wcd.topic.game-actions}", groupId = "${spring.kafka.consumer.group-id}")
    public void consume(GameActionV1 event) {
        try {
            logger.debug("Processing event: {}", event);

            switch (event.getAction()) {
                case "HEARTBEAT":
                    projectionService.updatePresence(event);
                    heartbeatCounter.increment();
                    break;
                case "DRINK":
                    projectionService.updateLeaderboard(event);
                    projectionService.updateUniques(event);
                    drinkCounter.increment();
                    break;
                default:
                    logger.warn("Unknown action type: {}", event.getAction());
            }
        } catch (Exception e) {
            logger.error("Error processing event: {}", event, e);
        }
    }
}
