import axios from 'axios'

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost'
const INGEST_PORT = import.meta.env.VITE_INGEST_PORT || '8081'
const QUERY_PORT = import.meta.env.VITE_QUERY_PORT || '8083'
const API_KEY = import.meta.env.VITE_API_KEY || 'dev-secret-key'

const ingestClient = axios.create({
  baseURL: `${API_BASE}:${INGEST_PORT}`,
  headers: {
    'X-API-KEY': API_KEY,
    'Content-Type': 'application/json'
  }
})

const queryClient = axios.create({
  baseURL: `${API_BASE}:${QUERY_PORT}`,
  headers: {
    'Content-Type': 'application/json'
  }
})

export interface GameAction {
  userId: string
  region: string
  matchId: string
  action?: string
  amount: number
  timestamp?: number
}

export interface LeaderboardEntry {
  userId: string
  score: number
  rank: number
}

export const api = {
  // Ingest endpoints
  sendHeartbeat: (data: GameAction) =>
    ingestClient.post('/api/events/heartbeat', data),

  sendDrink: (data: GameAction) =>
    ingestClient.post('/api/events/drink', data),

  // Query endpoints
  getHealth: () =>
    queryClient.get('/api/health'),

  getOnlineCount: () =>
    queryClient.get('/api/presence/onlineCount'),

  getLeaderboard: (matchId: string = 'match-1', limit: number = 10) =>
    queryClient.get(`/api/leaderboard?matchId=${matchId}&limit=${limit}`)
}
