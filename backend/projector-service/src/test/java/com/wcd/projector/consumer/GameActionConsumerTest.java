package com.wcd.projector.consumer;

import com.wcd.common.events.GameActionV1;
import com.wcd.projector.service.ProjectionService;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class GameActionConsumerTest {

    @Mock
    private ProjectionService projectionService;

    private MeterRegistry meterRegistry;
    private GameActionConsumer consumer;

    @BeforeEach
    void setUp() {
        meterRegistry = new SimpleMeterRegistry();
        consumer = new GameActionConsumer(projectionService, meterRegistry);
    }

    @Test
    void consume_HeartbeatEvent_UpdatesPresence() {
        GameActionV1 event = createEvent("user-1", "EU", "match-1", "HEARTBEAT", 0);

        consumer.consume(event);

        verify(projectionService).updatePresence(event);
        verify(projectionService, never()).updateLeaderboard(any());
        verify(projectionService, never()).updateUniques(any());
    }

    @Test
    void consume_HeartbeatEvent_IncrementsCounter() {
        GameActionV1 event = createEvent("user-1", "EU", "match-1", "HEARTBEAT", 0);
        double initialCount = getCounterValue("wcd.projector.heartbeat");

        consumer.consume(event);

        double newCount = getCounterValue("wcd.projector.heartbeat");
        assertEquals(initialCount + 1, newCount);
    }

    @Test
    void consume_DrinkEvent_UpdatesLeaderboardAndUniques() {
        GameActionV1 event = createEvent("user-2", "NA", "match-1", "DRINK", 2);

        consumer.consume(event);

        verify(projectionService).updateLeaderboard(event);
        verify(projectionService).updateUniques(event);
        verify(projectionService, never()).updatePresence(any());
    }

    @Test
    void consume_DrinkEvent_IncrementsCounter() {
        GameActionV1 event = createEvent("user-2", "NA", "match-1", "DRINK", 2);
        double initialCount = getCounterValue("wcd.projector.drink");

        consumer.consume(event);

        double newCount = getCounterValue("wcd.projector.drink");
        assertEquals(initialCount + 1, newCount);
    }

    @Test
    void consume_UnknownAction_DoesNothing() {
        GameActionV1 event = createEvent("user-3", "APAC", "match-1", "UNKNOWN_ACTION", 0);

        consumer.consume(event);

        verify(projectionService, never()).updatePresence(any());
        verify(projectionService, never()).updateLeaderboard(any());
        verify(projectionService, never()).updateUniques(any());
    }

    @Test
    void consume_NullAction_DoesNothing() {
        GameActionV1 event = createEvent("user-4", "EU", "match-1", null, 0);

        // Should not throw exception
        assertDoesNotThrow(() -> consumer.consume(event));

        verify(projectionService, never()).updatePresence(any());
        verify(projectionService, never()).updateLeaderboard(any());
        verify(projectionService, never()).updateUniques(any());
    }

    @Test
    void consume_ServiceThrowsException_HandlesGracefully() {
        GameActionV1 event = createEvent("user-5", "EU", "match-1", "HEARTBEAT", 0);
        doThrow(new RuntimeException("Redis unavailable")).when(projectionService).updatePresence(any());

        // Should not throw exception - it's handled internally
        assertDoesNotThrow(() -> consumer.consume(event));
    }

    @Test
    void consume_MultipleHeartbeats_ProcessesAll() {
        GameActionV1 event1 = createEvent("user-1", "EU", "match-1", "HEARTBEAT", 0);
        GameActionV1 event2 = createEvent("user-2", "NA", "match-1", "HEARTBEAT", 0);
        GameActionV1 event3 = createEvent("user-3", "APAC", "match-1", "HEARTBEAT", 0);

        consumer.consume(event1);
        consumer.consume(event2);
        consumer.consume(event3);

        verify(projectionService, times(3)).updatePresence(any());
    }

    @Test
    void consume_MultipleDrinks_ProcessesAll() {
        GameActionV1 event1 = createEvent("user-1", "EU", "match-1", "DRINK", 1);
        GameActionV1 event2 = createEvent("user-1", "EU", "match-1", "DRINK", 2);
        GameActionV1 event3 = createEvent("user-1", "EU", "match-1", "DRINK", 3);

        consumer.consume(event1);
        consumer.consume(event2);
        consumer.consume(event3);

        verify(projectionService, times(3)).updateLeaderboard(any());
        verify(projectionService, times(3)).updateUniques(any());
    }

    @Test
    void consume_MixedEvents_ProcessesCorrectly() {
        GameActionV1 heartbeat = createEvent("user-1", "EU", "match-1", "HEARTBEAT", 0);
        GameActionV1 drink = createEvent("user-2", "NA", "match-1", "DRINK", 1);

        consumer.consume(heartbeat);
        consumer.consume(drink);

        verify(projectionService, times(1)).updatePresence(heartbeat);
        verify(projectionService, times(1)).updateLeaderboard(drink);
        verify(projectionService, times(1)).updateUniques(drink);
    }

    @Test
    void consume_CasesSensitiveAction_OnlyMatchesExact() {
        GameActionV1 lowercaseHeartbeat = createEvent("user-1", "EU", "match-1", "heartbeat", 0);
        GameActionV1 mixedCaseDrink = createEvent("user-2", "NA", "match-1", "Drink", 1);

        consumer.consume(lowercaseHeartbeat);
        consumer.consume(mixedCaseDrink);

        // Should not match - actions are case-sensitive
        verify(projectionService, never()).updatePresence(any());
        verify(projectionService, never()).updateLeaderboard(any());
    }

    private GameActionV1 createEvent(String userId, String region, String matchId, String action, int amount) {
        GameActionV1 event = new GameActionV1();
        event.setUserId(userId);
        event.setRegion(region);
        event.setMatchId(matchId);
        event.setAction(action);
        event.setAmount(amount);
        event.setTimestamp(System.currentTimeMillis());
        return event;
    }

    private double getCounterValue(String counterName) {
        Counter counter = meterRegistry.find(counterName).counter();
        return counter != null ? counter.count() : 0;
    }
}
