import { http, HttpResponse } from 'msw'

export const handlers = [
  // Health endpoint
  http.get('http://localhost:8083/api/health', () => {
    return HttpResponse.json({ status: 'UP', timestamp: Date.now() })
  }),

  // Presence endpoint
  http.get('http://localhost:8083/api/presence/onlineCount', () => {
    return HttpResponse.json({ onlineCount: 42, timestamp: Date.now() })
  }),

  // Leaderboard endpoint
  http.get('http://localhost:8083/api/leaderboard', ({ request }) => {
    const url = new URL(request.url)
    const matchId = url.searchParams.get('matchId') || 'match-1'
    return HttpResponse.json({
      matchId,
      entries: [
        { userId: 'user-1', score: 100, rank: 1 },
        { userId: 'user-2', score: 80, rank: 2 },
        { userId: 'user-3', score: 60, rank: 3 }
      ],
      timestamp: Date.now()
    })
  }),

  // Heartbeat endpoint
  http.post('http://localhost:8081/api/events/heartbeat', () => {
    return HttpResponse.json({ status: 'accepted' }, { status: 202 })
  }),

  // Drink endpoint
  http.post('http://localhost:8081/api/events/drink', () => {
    return HttpResponse.json({ status: 'accepted' }, { status: 202 })
  })
]

// Error handlers for testing error states
export const errorHandlers = {
  healthDown: http.get('http://localhost:8083/api/health', () => {
    return HttpResponse.json({ status: 'DOWN' }, { status: 503 })
  }),

  healthError: http.get('http://localhost:8083/api/health', () => {
    return HttpResponse.error()
  }),

  presenceError: http.get('http://localhost:8083/api/presence/onlineCount', () => {
    return HttpResponse.error()
  }),

  leaderboardError: http.get('http://localhost:8083/api/leaderboard', () => {
    return HttpResponse.error()
  }),

  leaderboardEmpty: http.get('http://localhost:8083/api/leaderboard', ({ request }) => {
    const url = new URL(request.url)
    const matchId = url.searchParams.get('matchId') || 'match-1'
    return HttpResponse.json({
      matchId,
      entries: [],
      timestamp: Date.now()
    })
  }),

  heartbeatRateLimit: http.post('http://localhost:8081/api/events/heartbeat', () => {
    return HttpResponse.json({ error: 'Rate limit exceeded' }, { status: 429 })
  }),

  drinkError: http.post('http://localhost:8081/api/events/drink', () => {
    return HttpResponse.json({ error: 'Internal server error' }, { status: 500 })
  })
}
