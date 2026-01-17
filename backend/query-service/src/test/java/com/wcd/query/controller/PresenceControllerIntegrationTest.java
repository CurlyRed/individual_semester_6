package com.wcd.query.controller;

import com.wcd.query.service.PresenceService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(PresenceController.class)
class PresenceControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PresenceService presenceService;

    @Test
    void onlineCount_ReturnsJsonResponse() throws Exception {
        when(presenceService.getOnlineCount()).thenReturn(0L);

        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    void onlineCount_ReturnsOnlineCount() throws Exception {
        when(presenceService.getOnlineCount()).thenReturn(42L);

        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.onlineCount").value(42));
    }

    @Test
    void onlineCount_ReturnsTimestamp() throws Exception {
        when(presenceService.getOnlineCount()).thenReturn(0L);

        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.timestamp").isNumber());
    }

    @Test
    void onlineCount_ZeroUsers_ReturnsZero() throws Exception {
        when(presenceService.getOnlineCount()).thenReturn(0L);

        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.onlineCount").value(0));
    }

    @Test
    void onlineCount_LargeNumber_ReturnsCorrectValue() throws Exception {
        when(presenceService.getOnlineCount()).thenReturn(1_000_000L);

        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.onlineCount").value(1000000));
    }

    @Test
    void onlineCount_PostMethod_NotAllowed() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .post("/api/presence/onlineCount"))
            .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void onlineCount_PutMethod_NotAllowed() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .put("/api/presence/onlineCount"))
            .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void onlineCount_DeleteMethod_NotAllowed() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                .delete("/api/presence/onlineCount"))
            .andExpect(status().isMethodNotAllowed());
    }

    @Test
    void onlineCount_ServiceError_PropagatesException() throws Exception {
        when(presenceService.getOnlineCount())
            .thenThrow(new RuntimeException("Redis connection failed"));

        // When service throws exception, Spring will handle it
        mockMvc.perform(get("/api/presence/onlineCount"))
            .andExpect(result -> {
                int status = result.getResponse().getStatus();
                assert status >= 400 : "Expected error status code";
            });
    }

    @Test
    void wrongEndpoint_Returns404() throws Exception {
        mockMvc.perform(get("/api/presence/wrongEndpoint"))
            .andExpect(status().isNotFound());
    }

    @Test
    void basePresenceEndpoint_Returns404() throws Exception {
        mockMvc.perform(get("/api/presence"))
            .andExpect(status().isNotFound());
    }
}
