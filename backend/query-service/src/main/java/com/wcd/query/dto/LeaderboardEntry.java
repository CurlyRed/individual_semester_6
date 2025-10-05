package com.wcd.query.dto;

public class LeaderboardEntry {

    private String userId;
    private double score;
    private int rank;

    public LeaderboardEntry() {
    }

    public LeaderboardEntry(String userId, double score, int rank) {
        this.userId = userId;
        this.score = score;
        this.rank = rank;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public double getScore() {
        return score;
    }

    public void setScore(double score) {
        this.score = score;
    }

    public int getRank() {
        return rank;
    }

    public void setRank(int rank) {
        this.rank = rank;
    }
}
