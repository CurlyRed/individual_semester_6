package com.wcd.query.controller;

import com.wcd.query.dto.LeaderboardEntry;
import com.wcd.query.service.LeaderboardService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LeaderboardControllerTest {

    @Mock
    private LeaderboardService leaderboardService;

    private LeaderboardController controller;

    @BeforeEach
    void setUp() {
        controller = new LeaderboardController(leaderboardService);
    }

    @Test
    void getLeaderboard_WithDefaultParams_UsesDefaultMatchIdAndLimit() {
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(Collections.emptyList());

        controller.getLeaderboard("match-1", 10);

        verify(leaderboardService).getTopPlayers("match-1", 10);
    }

    @Test
    void getLeaderboard_ReturnsMatchIdInResponse() {
        String matchId = "world-cup-finals";
        when(leaderboardService.getTopPlayers(matchId, 10)).thenReturn(Collections.emptyList());

        Map<String, Object> response = controller.getLeaderboard(matchId, 10);

        assertEquals(matchId, response.get("matchId"));
    }

    @Test
    void getLeaderboard_ReturnsEntriesFromService() {
        List<LeaderboardEntry> entries = new ArrayList<>();
        entries.add(new LeaderboardEntry("user-1", 100.0, 1));
        entries.add(new LeaderboardEntry("user-2", 90.0, 2));
        entries.add(new LeaderboardEntry("user-3", 80.0, 3));
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(entries);

        Map<String, Object> response = controller.getLeaderboard("match-1", 10);

        @SuppressWarnings("unchecked")
        List<LeaderboardEntry> returnedEntries = (List<LeaderboardEntry>) response.get("entries");
        assertEquals(3, returnedEntries.size());
        assertEquals("user-1", returnedEntries.get(0).getUserId());
        assertEquals(100.0, returnedEntries.get(0).getScore());
    }

    @Test
    void getLeaderboard_ReturnsTimestamp() {
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(Collections.emptyList());
        long beforeCall = System.currentTimeMillis();

        Map<String, Object> response = controller.getLeaderboard("match-1", 10);

        long afterCall = System.currentTimeMillis();
        long timestamp = (Long) response.get("timestamp");

        assertTrue(timestamp >= beforeCall && timestamp <= afterCall);
    }

    @Test
    void getLeaderboard_ReturnsMapWithThreeEntries() {
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(Collections.emptyList());

        Map<String, Object> response = controller.getLeaderboard("match-1", 10);

        assertEquals(3, response.size());
        assertTrue(response.containsKey("matchId"));
        assertTrue(response.containsKey("entries"));
        assertTrue(response.containsKey("timestamp"));
    }

    @Test
    void getLeaderboard_WithCustomLimit_PassesLimitToService() {
        when(leaderboardService.getTopPlayers("match-1", 50)).thenReturn(Collections.emptyList());

        controller.getLeaderboard("match-1", 50);

        verify(leaderboardService).getTopPlayers("match-1", 50);
    }

    @Test
    void getLeaderboard_WithEmptyResult_ReturnsEmptyList() {
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(Collections.emptyList());

        Map<String, Object> response = controller.getLeaderboard("match-1", 10);

        @SuppressWarnings("unchecked")
        List<LeaderboardEntry> entries = (List<LeaderboardEntry>) response.get("entries");
        assertTrue(entries.isEmpty());
    }

    @Test
    void getLeaderboard_ServiceException_Propagates() {
        when(leaderboardService.getTopPlayers(anyString(), anyInt()))
            .thenThrow(new RuntimeException("Redis unavailable"));

        assertThrows(RuntimeException.class, () -> controller.getLeaderboard("match-1", 10));
    }

    @Test
    void getLeaderboard_DifferentMatchIds_CallsServiceWithCorrectId() {
        when(leaderboardService.getTopPlayers(anyString(), anyInt())).thenReturn(Collections.emptyList());

        controller.getLeaderboard("match-A", 10);
        controller.getLeaderboard("match-B", 10);
        controller.getLeaderboard("match-C", 10);

        verify(leaderboardService).getTopPlayers("match-A", 10);
        verify(leaderboardService).getTopPlayers("match-B", 10);
        verify(leaderboardService).getTopPlayers("match-C", 10);
    }

    @Test
    void getLeaderboard_LimitOfOne_ReturnsTopPlayer() {
        List<LeaderboardEntry> entries = new ArrayList<>();
        entries.add(new LeaderboardEntry("champion", 500.0, 1));
        when(leaderboardService.getTopPlayers("finals", 1)).thenReturn(entries);

        Map<String, Object> response = controller.getLeaderboard("finals", 1);

        @SuppressWarnings("unchecked")
        List<LeaderboardEntry> returnedEntries = (List<LeaderboardEntry>) response.get("entries");
        assertEquals(1, returnedEntries.size());
        assertEquals("champion", returnedEntries.get(0).getUserId());
    }

    @Test
    void getLeaderboard_PreservesEntryOrder() {
        List<LeaderboardEntry> entries = new ArrayList<>();
        entries.add(new LeaderboardEntry("first", 300.0, 1));
        entries.add(new LeaderboardEntry("second", 200.0, 2));
        entries.add(new LeaderboardEntry("third", 100.0, 3));
        when(leaderboardService.getTopPlayers("match-1", 10)).thenReturn(entries);

        Map<String, Object> response = controller.getLeaderboard("match-1", 10);

        @SuppressWarnings("unchecked")
        List<LeaderboardEntry> returnedEntries = (List<LeaderboardEntry>) response.get("entries");
        assertEquals("first", returnedEntries.get(0).getUserId());
        assertEquals("second", returnedEntries.get(1).getUserId());
        assertEquals("third", returnedEntries.get(2).getUserId());
    }
}
