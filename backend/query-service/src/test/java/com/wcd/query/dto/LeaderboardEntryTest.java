package com.wcd.query.dto;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class LeaderboardEntryTest {

    @Test
    void constructor_SetsAllFields() {
        LeaderboardEntry entry = new LeaderboardEntry("user-1", 100.5, 1);

        assertEquals("user-1", entry.getUserId());
        assertEquals(100.5, entry.getScore());
        assertEquals(1, entry.getRank());
    }

    @Test
    void defaultConstructor_CreatesEmptyEntry() {
        LeaderboardEntry entry = new LeaderboardEntry();

        assertNull(entry.getUserId());
        assertEquals(0.0, entry.getScore());
        assertEquals(0, entry.getRank());
    }

    @Test
    void setUserId_UpdatesUserId() {
        LeaderboardEntry entry = new LeaderboardEntry();
        entry.setUserId("test-user");

        assertEquals("test-user", entry.getUserId());
    }

    @Test
    void setScore_UpdatesScore() {
        LeaderboardEntry entry = new LeaderboardEntry();
        entry.setScore(250.75);

        assertEquals(250.75, entry.getScore());
    }

    @Test
    void setRank_UpdatesRank() {
        LeaderboardEntry entry = new LeaderboardEntry();
        entry.setRank(5);

        assertEquals(5, entry.getRank());
    }

    @Test
    void score_CanBeZero() {
        LeaderboardEntry entry = new LeaderboardEntry("user", 0.0, 1);

        assertEquals(0.0, entry.getScore());
    }

    @Test
    void score_CanBeNegative() {
        LeaderboardEntry entry = new LeaderboardEntry("user", -10.0, 1);

        assertEquals(-10.0, entry.getScore());
    }

    @Test
    void score_CanBeLargeNumber() {
        LeaderboardEntry entry = new LeaderboardEntry("user", Double.MAX_VALUE, 1);

        assertEquals(Double.MAX_VALUE, entry.getScore());
    }

    @Test
    void rank_CanBeZero() {
        LeaderboardEntry entry = new LeaderboardEntry("user", 100.0, 0);

        assertEquals(0, entry.getRank());
    }

    @Test
    void rank_CanBeNegative() {
        LeaderboardEntry entry = new LeaderboardEntry("user", 100.0, -1);

        assertEquals(-1, entry.getRank());
    }

    @Test
    void userId_CanBeNull() {
        LeaderboardEntry entry = new LeaderboardEntry(null, 100.0, 1);

        assertNull(entry.getUserId());
    }

    @Test
    void userId_CanBeEmpty() {
        LeaderboardEntry entry = new LeaderboardEntry("", 100.0, 1);

        assertEquals("", entry.getUserId());
    }

    @Test
    void allFieldsCanBeModified() {
        LeaderboardEntry entry = new LeaderboardEntry("original", 50.0, 10);

        entry.setUserId("modified");
        entry.setScore(150.0);
        entry.setRank(1);

        assertEquals("modified", entry.getUserId());
        assertEquals(150.0, entry.getScore());
        assertEquals(1, entry.getRank());
    }

    @Test
    void multipleEntriesAreIndependent() {
        LeaderboardEntry entry1 = new LeaderboardEntry("user-1", 100.0, 1);
        LeaderboardEntry entry2 = new LeaderboardEntry("user-2", 200.0, 2);

        assertEquals("user-1", entry1.getUserId());
        assertEquals("user-2", entry2.getUserId());
        assertNotEquals(entry1.getScore(), entry2.getScore());
        assertNotEquals(entry1.getRank(), entry2.getRank());
    }
}
