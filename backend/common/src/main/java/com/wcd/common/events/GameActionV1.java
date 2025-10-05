package com.wcd.common.events;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Objects;

public class GameActionV1 {

    @JsonProperty("userId")
    private String userId;

    @JsonProperty("region")
    private String region;

    @JsonProperty("matchId")
    private String matchId;

    @JsonProperty("action")
    private String action;

    @JsonProperty("amount")
    private int amount;

    @JsonProperty("timestamp")
    private long timestamp;

    public GameActionV1() {
    }

    public GameActionV1(String userId, String region, String matchId, String action, int amount, long timestamp) {
        this.userId = userId;
        this.region = region;
        this.matchId = matchId;
        this.action = action;
        this.amount = amount;
        this.timestamp = timestamp;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getRegion() {
        return region;
    }

    public void setRegion(String region) {
        this.region = region;
    }

    public String getMatchId() {
        return matchId;
    }

    public void setMatchId(String matchId) {
        this.matchId = matchId;
    }

    public String getAction() {
        return action;
    }

    public void setAction(String action) {
        this.action = action;
    }

    public int getAmount() {
        return amount;
    }

    public void setAmount(int amount) {
        this.amount = amount;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        GameActionV1 that = (GameActionV1) o;
        return amount == that.amount &&
               timestamp == that.timestamp &&
               Objects.equals(userId, that.userId) &&
               Objects.equals(region, that.region) &&
               Objects.equals(matchId, that.matchId) &&
               Objects.equals(action, that.action);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, region, matchId, action, amount, timestamp);
    }

    @Override
    public String toString() {
        return "GameActionV1{" +
               "userId='" + userId + '\'' +
               ", region='" + region + '\'' +
               ", matchId='" + matchId + '\'' +
               ", action='" + action + '\'' +
               ", amount=" + amount +
               ", timestamp=" + timestamp +
               '}';
    }
}
