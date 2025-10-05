package com.wcd.query.controller;

import com.wcd.query.dto.LeaderboardEntry;
import com.wcd.query.service.LeaderboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/leaderboard")
public class LeaderboardController {

    private final LeaderboardService leaderboardService;

    public LeaderboardController(LeaderboardService leaderboardService) {
        this.leaderboardService = leaderboardService;
    }

    @GetMapping
    public Map<String, Object> getLeaderboard(
        @RequestParam(defaultValue = "match-1") String matchId,
        @RequestParam(defaultValue = "10") int limit
    ) {
        List<LeaderboardEntry> entries = leaderboardService.getTopPlayers(matchId, limit);
        return Map.of(
            "matchId", matchId,
            "entries", entries,
            "timestamp", System.currentTimeMillis()
        );
    }
}
