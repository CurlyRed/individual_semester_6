import axios from 'axios'

// In GKE: use relative URLs (nginx proxies to services)
// Locally: use localhost with ports
const isProduction = import.meta.env.PROD
const API_KEY = import.meta.env.VITE_API_KEY || 'dev-secret-key'

const ingestClient = axios.create({
  baseURL: isProduction ? '/ingest' : 'http://localhost:8081',
  headers: {
    'X-API-KEY': API_KEY,
    'Content-Type': 'application/json'
  }
})

const queryClient = axios.create({
  baseURL: isProduction ? '/query' : 'http://localhost:8083',
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
