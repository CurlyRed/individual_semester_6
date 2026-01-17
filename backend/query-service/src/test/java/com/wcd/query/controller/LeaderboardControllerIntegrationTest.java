package com.wcd.query.controller;

import com.wcd.query.dto.LeaderboardEntry;
import com.wcd.query.service.LeaderboardService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(LeaderboardController.class)
class LeaderboardControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private LeaderboardService leaderboardService;

    @Test
    void getLeaderboard_ReturnsJsonResponse() throws Exception {
        when(leaderboardService.getTopPlayers(anyString(), anyInt()))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard"))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    void getLeaderboard_DefaultParams_ReturnsMatchId() throws Exception {
        when(leaderboardService.getTopPlayers("match-1", 10))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.matchId").value("match-1"));
    }

    @Test
    void getLeaderboard_WithCustomMatchId_ReturnsCorrectMatchId() throws Exception {
        when(leaderboardService.getTopPlayers("custom-match", 10))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard")
                .param("matchId", "custom-match"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.matchId").value("custom-match"));
    }

    @Test
    void getLeaderboard_WithCustomLimit_PassesLimitToService() throws Exception {
        when(leaderboardService.getTopPlayers("match-1", 25))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard")
                .param("limit", "25"))
            .andExpect(status().isOk());
    }

    @Test
    void getLeaderboard_ReturnsEntries() throws Exception {
        List<LeaderboardEntry> entries = new ArrayList<>();
        entries.add(new LeaderboardEntry("champion", 500.0, 1));
        entries.add(new LeaderboardEntry("runner-up", 400.0, 2));
        when(leaderboardService.getTopPlayers("match-1", 10))
            .thenReturn(entries);

        mockMvc.perform(get("/api/leaderboard"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.entries").isArray())
            .andExpect(jsonPath("$.entries.length()").value(2))
            .andExpect(jsonPath("$.entries[0].userId").value("champion"))
            .andExpect(jsonPath("$.entries[0].score").value(500.0))
            .andExpect(jsonPath("$.entries[0].rank").value(1))
            .andExpect(jsonPath("$.entries[1].userId").value("runner-up"));
    }

    @Test
    void getLeaderboard_ReturnsTimestamp() throws Exception {
        when(leaderboardService.getTopPlayers(anyString(), anyInt()))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.timestamp").isNumber());
    }

    @Test
    void getLeaderboard_EmptyResult_ReturnsEmptyArray() throws Exception {
        when(leaderboardService.getTopPlayers(anyString(), anyInt()))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.entries").isArray())
            .andExpect(jsonPath("$.entries").isEmpty());
    }

    @Test
    void getLeaderboard_PostMethod_NotAllowed() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .post("/api/leaderboard"))
            .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void getLeaderboard_ServiceError_PropagatesException() {
        when(leaderboardService.getTopPlayers(anyString(), anyInt()))
            .thenThrow(new RuntimeException("Database error"));

        // When service throws exception without global handler, it propagates as ServletException
        assertThrows(Exception.class, () ->
            mockMvc.perform(get("/api/leaderboard"))
        );
    }

    @Test
    void getLeaderboard_WithBothParams_UsesBoth() throws Exception {
        when(leaderboardService.getTopPlayers("world-cup", 100))
            .thenReturn(Collections.emptyList());

        mockMvc.perform(get("/api/leaderboard")
                .param("matchId", "world-cup")
                .param("limit", "100"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.matchId").value("world-cup"));
    }
}
