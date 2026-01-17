package com.wcd.query.controller;

import com.wcd.query.service.PresenceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PresenceControllerTest {

    @Mock
    private PresenceService presenceService;

    private PresenceController controller;

    @BeforeEach
    void setUp() {
        controller = new PresenceController(presenceService);
    }

    @Test
    void onlineCount_ReturnsOnlineCountFromService() {
        when(presenceService.getOnlineCount()).thenReturn(42L);

        Map<String, Object> response = controller.onlineCount();

        assertEquals(42L, response.get("onlineCount"));
        verify(presenceService).getOnlineCount();
    }

    @Test
    void onlineCount_ReturnsTimestamp() {
        when(presenceService.getOnlineCount()).thenReturn(0L);
        long beforeCall = System.currentTimeMillis();

        Map<String, Object> response = controller.onlineCount();

        long afterCall = System.currentTimeMillis();
        long timestamp = (Long) response.get("timestamp");

        assertTrue(timestamp >= beforeCall && timestamp <= afterCall);
    }

    @Test
    void onlineCount_ReturnsMapWithTwoEntries() {
        when(presenceService.getOnlineCount()).thenReturn(100L);

        Map<String, Object> response = controller.onlineCount();

        assertEquals(2, response.size());
        assertTrue(response.containsKey("onlineCount"));
        assertTrue(response.containsKey("timestamp"));
    }

    @Test
    void onlineCount_WithZeroUsers_ReturnsZero() {
        when(presenceService.getOnlineCount()).thenReturn(0L);

        Map<String, Object> response = controller.onlineCount();

        assertEquals(0L, response.get("onlineCount"));
    }

    @Test
    void onlineCount_WithLargeNumber_ReturnsCorrectValue() {
        when(presenceService.getOnlineCount()).thenReturn(1_000_000L);

        Map<String, Object> response = controller.onlineCount();

        assertEquals(1_000_000L, response.get("onlineCount"));
    }

    @Test
    void onlineCount_ServiceException_Propagates() {
        when(presenceService.getOnlineCount()).thenThrow(new RuntimeException("Redis connection failed"));

        assertThrows(RuntimeException.class, () -> controller.onlineCount());
    }

    @Test
    void onlineCount_MultipleCalls_CallsServiceEachTime() {
        when(presenceService.getOnlineCount()).thenReturn(10L, 20L, 30L);

        Map<String, Object> response1 = controller.onlineCount();
        Map<String, Object> response2 = controller.onlineCount();
        Map<String, Object> response3 = controller.onlineCount();

        assertEquals(10L, response1.get("onlineCount"));
        assertEquals(20L, response2.get("onlineCount"));
        assertEquals(30L, response3.get("onlineCount"));
        verify(presenceService, times(3)).getOnlineCount();
    }
}
