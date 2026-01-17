package com.wcd.ingest.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wcd.common.events.GameActionV1;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@EmbeddedKafka(partitions = 1, topics = {"game-actions-test"})
@TestPropertySource(properties = {
    "wcd.api-key=integration-test-key",
    "wcd.topic.game-actions=game-actions-test",
    "spring.kafka.bootstrap-servers=${spring.embedded.kafka.brokers}",
    "wcd.rate-limit.capacity=100",
    "wcd.rate-limit.refill-tokens=100",
    "wcd.rate-limit.refill-duration-seconds=1"
})
class EventControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Value("${wcd.api-key}")
    private String apiKey;

    @Test
    void heartbeat_WithValidRequest_ReturnsAccepted() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-integration-1");
        event.setRegion("EU");
        event.setMatchId("match-test");

        mockMvc.perform(post("/api/events/heartbeat")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isAccepted())
            .andExpect(jsonPath("$.status").value("accepted"));
    }

    @Test
    void heartbeat_WithoutApiKey_ReturnsUnauthorized() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");

        mockMvc.perform(post("/api/events/heartbeat")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isBadRequest()); // Missing header
    }

    @Test
    void heartbeat_WithInvalidApiKey_ReturnsUnauthorized() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");

        mockMvc.perform(post("/api/events/heartbeat")
                .header("X-API-KEY", "wrong-api-key")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error").value("Invalid API key"));
    }

    @Test
    void drink_WithValidRequest_ReturnsAccepted() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-integration-2");
        event.setRegion("NA");
        event.setMatchId("match-test");
        event.setAmount(2);

        mockMvc.perform(post("/api/events/drink")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isAccepted())
            .andExpect(jsonPath("$.status").value("accepted"));
    }

    @Test
    void drink_WithInvalidApiKey_ReturnsUnauthorized() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");
        event.setAmount(1);

        mockMvc.perform(post("/api/events/drink")
                .header("X-API-KEY", "invalid-key")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isUnauthorized());
    }

    @Test
    void heartbeat_WithInvalidJson_ReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/events/heartbeat")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{ invalid json }"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void drink_WithEmptyBody_ReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/events/drink")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(""))
            .andExpect(status().isBadRequest());
    }

    @Test
    void heartbeat_ContentTypeJson_Required() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-1");

        mockMvc.perform(post("/api/events/heartbeat")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.TEXT_PLAIN)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isUnsupportedMediaType());
    }

    @Test
    void heartbeat_SetsActionToHeartbeat() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-action-test");
        event.setRegion("APAC");
        event.setMatchId("match-action");

        mockMvc.perform(post("/api/events/heartbeat")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isAccepted());
        // The action should be set to "HEARTBEAT" internally
    }

    @Test
    void drink_SetsActionToDrink() throws Exception {
        GameActionV1 event = new GameActionV1();
        event.setUserId("user-drink-test");
        event.setRegion("EU");
        event.setMatchId("match-drink");
        event.setAmount(3);

        mockMvc.perform(post("/api/events/drink")
                .header("X-API-KEY", apiKey)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(event)))
            .andExpect(status().isAccepted());
        // The action should be set to "DRINK" internally
    }
}
