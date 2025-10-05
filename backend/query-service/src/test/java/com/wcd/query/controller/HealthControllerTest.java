package com.wcd.query.controller;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class HealthControllerTest {

    @Test
    void health_ShouldReturnUpStatus() {
        HealthController controller = new HealthController();

        Map<String, Object> response = controller.health();

        assertEquals("UP", response.get("status"));
        assertNotNull(response.get("timestamp"));
        assertTrue(response.get("timestamp") instanceof Long);
    }
}
