package com.wcd.common.events;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class GameActionV1Test {

    @Test
    void testConstructorAndGetters() {
        GameActionV1 event = new GameActionV1(
            "user-123",
            "EU",
            "match-1",
            "DRINK",
            2,
            System.currentTimeMillis()
        );

        assertEquals("user-123", event.getUserId());
        assertEquals("EU", event.getRegion());
        assertEquals("match-1", event.getMatchId());
        assertEquals("DRINK", event.getAction());
        assertEquals(2, event.getAmount());
    }

    @Test
    void testEqualsAndHashCode() {
        long timestamp = System.currentTimeMillis();
        GameActionV1 event1 = new GameActionV1("user-1", "EU", "match-1", "DRINK", 2, timestamp);
        GameActionV1 event2 = new GameActionV1("user-1", "EU", "match-1", "DRINK", 2, timestamp);
        GameActionV1 event3 = new GameActionV1("user-2", "NA", "match-1", "DRINK", 2, timestamp);

        assertEquals(event1, event2);
        assertNotEquals(event1, event3);
        assertEquals(event1.hashCode(), event2.hashCode());
    }
}
