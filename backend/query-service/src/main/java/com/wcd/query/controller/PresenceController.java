package com.wcd.query.controller;

import com.wcd.query.service.PresenceService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/presence")
public class PresenceController {

    private final PresenceService presenceService;

    public PresenceController(PresenceService presenceService) {
        this.presenceService = presenceService;
    }

    @GetMapping("/onlineCount")
    public Map<String, Object> onlineCount() {
        long count = presenceService.getOnlineCount();
        return Map.of(
            "onlineCount", count,
            "timestamp", System.currentTimeMillis()
        );
    }
}
