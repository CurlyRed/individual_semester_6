package com.wcd.ingest.service;

import com.wcd.common.events.GameActionV1;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.TopicPartition;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;

import java.util.concurrent.CompletableFuture;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class EventPublisherTest {

    @Mock
    private KafkaTemplate<String, GameActionV1> kafkaTemplate;

    private EventPublisher eventPublisher;
    private static final String TOPIC_NAME = "game-actions";

    @BeforeEach
    void setUp() {
        eventPublisher = new EventPublisher(kafkaTemplate, TOPIC_NAME);
    }

    @Test
    void publish_SendsEventToCorrectTopic() {
        GameActionV1 event = createTestEvent("user-123", "EU", "match-1", "HEARTBEAT");
        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), eq("user-123"), eq(event))).thenReturn(future);

        eventPublisher.publish(event);

        verify(kafkaTemplate).send(eq(TOPIC_NAME), eq("user-123"), eq(event));
    }

    @Test
    void publish_UsesUserIdAsKey() {
        String userId = "user-456";
        GameActionV1 event = createTestEvent(userId, "NA", "match-2", "DRINK");
        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), eq(userId), eq(event))).thenReturn(future);

        eventPublisher.publish(event);

        ArgumentCaptor<String> keyCaptor = ArgumentCaptor.forClass(String.class);
        verify(kafkaTemplate).send(eq(TOPIC_NAME), keyCaptor.capture(), any(GameActionV1.class));
        assertEquals(userId, keyCaptor.getValue());
    }

    @Test
    void publish_HandlesSuccessfulSend() {
        GameActionV1 event = createTestEvent("user-789", "APAC", "match-3", "HEARTBEAT");
        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), eq("user-789"), eq(event))).thenReturn(future);

        eventPublisher.publish(event);

        // Simulate successful send
        RecordMetadata metadata = new RecordMetadata(
            new TopicPartition(TOPIC_NAME, 0), 0, 0, 0, 0, 0
        );
        ProducerRecord<String, GameActionV1> record = new ProducerRecord<>(TOPIC_NAME, "user-789", event);
        SendResult<String, GameActionV1> sendResult = new SendResult<>(record, metadata);
        future.complete(sendResult);

        // Should complete without exception
        assertTrue(future.isDone());
        assertFalse(future.isCompletedExceptionally());
    }

    @Test
    void publish_HandlesFailedSend() {
        GameActionV1 event = createTestEvent("user-error", "EU", "match-4", "DRINK");
        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), eq("user-error"), eq(event))).thenReturn(future);

        eventPublisher.publish(event);

        // Simulate failed send
        future.completeExceptionally(new RuntimeException("Kafka unavailable"));

        assertTrue(future.isCompletedExceptionally());
    }

    @Test
    void publish_WithNullUserId_StillSendsEvent() {
        GameActionV1 event = createTestEvent(null, "EU", "match-5", "HEARTBEAT");
        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), isNull(), eq(event))).thenReturn(future);

        eventPublisher.publish(event);

        verify(kafkaTemplate).send(eq(TOPIC_NAME), isNull(), eq(event));
    }

    @Test
    void publish_MultipleEvents_SendsAll() {
        GameActionV1 event1 = createTestEvent("user-1", "EU", "match-1", "HEARTBEAT");
        GameActionV1 event2 = createTestEvent("user-2", "NA", "match-1", "DRINK");
        GameActionV1 event3 = createTestEvent("user-3", "APAC", "match-1", "HEARTBEAT");

        CompletableFuture<SendResult<String, GameActionV1>> future = new CompletableFuture<>();
        when(kafkaTemplate.send(eq(TOPIC_NAME), anyString(), any(GameActionV1.class))).thenReturn(future);

        eventPublisher.publish(event1);
        eventPublisher.publish(event2);
        eventPublisher.publish(event3);

        verify(kafkaTemplate, times(3)).send(eq(TOPIC_NAME), anyString(), any(GameActionV1.class));
    }

    private GameActionV1 createTestEvent(String userId, String region, String matchId, String action) {
        GameActionV1 event = new GameActionV1();
        event.setUserId(userId);
        event.setRegion(region);
        event.setMatchId(matchId);
        event.setAction(action);
        event.setAmount(action.equals("DRINK") ? 1 : 0);
        event.setTimestamp(System.currentTimeMillis());
        return event;
    }
}
