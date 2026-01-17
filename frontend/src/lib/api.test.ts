import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest'
import { server } from '../test/mocks/server'
import { http, HttpResponse } from 'msw'

// We need to mock import.meta.env before importing api
vi.stubGlobal('import', {
  meta: {
    env: {
      PROD: false,
      VITE_API_KEY: 'test-api-key'
    }
  }
})

// Import api after mocking
import { api, GameAction, LeaderboardEntry } from './api'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('api', () => {
  describe('sendHeartbeat', () => {
    it('sends heartbeat to correct endpoint', async () => {
      const data: GameAction = {
        userId: 'user-1',
        region: 'EU',
        matchId: 'match-1',
        amount: 0
      }

      const response = await api.sendHeartbeat(data)

      expect(response.status).toBe(202)
      expect(response.data.status).toBe('accepted')
    })

    it('includes all required fields', async () => {
      let capturedBody: GameAction | null = null

      server.use(
        http.post('http://localhost:8081/api/events/heartbeat', async ({ request }) => {
          capturedBody = await request.json() as GameAction
          return HttpResponse.json({ status: 'accepted' }, { status: 202 })
        })
      )

      const data: GameAction = {
        userId: 'test-user',
        region: 'NA',
        matchId: 'match-2',
        amount: 0
      }

      await api.sendHeartbeat(data)

      expect(capturedBody).toEqual(data)
    })
  })

  describe('sendDrink', () => {
    it('sends drink event to correct endpoint', async () => {
      const data: GameAction = {
        userId: 'user-1',
        region: 'EU',
        matchId: 'match-1',
        amount: 2
      }

      const response = await api.sendDrink(data)

      expect(response.status).toBe(202)
      expect(response.data.status).toBe('accepted')
    })

    it('includes amount in request', async () => {
      let capturedBody: GameAction | null = null

      server.use(
        http.post('http://localhost:8081/api/events/drink', async ({ request }) => {
          capturedBody = await request.json() as GameAction
          return HttpResponse.json({ status: 'accepted' }, { status: 202 })
        })
      )

      const data: GameAction = {
        userId: 'user-1',
        region: 'APAC',
        matchId: 'match-3',
        amount: 5
      }

      await api.sendDrink(data)

      expect(capturedBody?.amount).toBe(5)
    })
  })

  describe('getHealth', () => {
    it('fetches health status', async () => {
      const response = await api.getHealth()

      expect(response.status).toBe(200)
      expect(response.data.status).toBe('UP')
    })

    it('returns timestamp', async () => {
      const response = await api.getHealth()

      expect(response.data.timestamp).toBeDefined()
      expect(typeof response.data.timestamp).toBe('number')
    })
  })

  describe('getOnlineCount', () => {
    it('fetches online count', async () => {
      const response = await api.getOnlineCount()

      expect(response.status).toBe(200)
      expect(response.data.onlineCount).toBe(42)
    })

    it('returns timestamp', async () => {
      const response = await api.getOnlineCount()

      expect(response.data.timestamp).toBeDefined()
    })
  })

  describe('getLeaderboard', () => {
    it('fetches leaderboard with default parameters', async () => {
      const response = await api.getLeaderboard()

      expect(response.status).toBe(200)
      expect(response.data.matchId).toBe('match-1')
      expect(response.data.entries).toHaveLength(3)
    })

    it('fetches leaderboard with custom matchId', async () => {
      const response = await api.getLeaderboard('match-2')

      expect(response.data.matchId).toBe('match-2')
    })

    it('fetches leaderboard with custom limit', async () => {
      let capturedUrl = ''

      server.use(
        http.get('http://localhost:8083/api/leaderboard', ({ request }) => {
          capturedUrl = request.url
          return HttpResponse.json({
            matchId: 'match-1',
            entries: [],
            timestamp: Date.now()
          })
        })
      )

      await api.getLeaderboard('match-1', 25)

      expect(capturedUrl).toContain('limit=25')
    })

    it('returns entries with correct structure', async () => {
      const response = await api.getLeaderboard()

      const entry: LeaderboardEntry = response.data.entries[0]
      expect(entry.userId).toBeDefined()
      expect(entry.score).toBeDefined()
      expect(entry.rank).toBeDefined()
    })

    it('entries are sorted by rank', async () => {
      const response = await api.getLeaderboard()

      const entries: LeaderboardEntry[] = response.data.entries
      expect(entries[0].rank).toBe(1)
      expect(entries[1].rank).toBe(2)
      expect(entries[2].rank).toBe(3)
    })
  })

  describe('error handling', () => {
    it('throws on network error for heartbeat', async () => {
      server.use(
        http.post('http://localhost:8081/api/events/heartbeat', () => {
          return HttpResponse.error()
        })
      )

      const data: GameAction = {
        userId: 'user-1',
        region: 'EU',
        matchId: 'match-1',
        amount: 0
      }

      await expect(api.sendHeartbeat(data)).rejects.toThrow()
    })

    it('throws on network error for health', async () => {
      server.use(
        http.get('http://localhost:8083/api/health', () => {
          return HttpResponse.error()
        })
      )

      await expect(api.getHealth()).rejects.toThrow()
    })

    it('handles 429 rate limit response', async () => {
      server.use(
        http.post('http://localhost:8081/api/events/heartbeat', () => {
          return HttpResponse.json({ error: 'Rate limit exceeded' }, { status: 429 })
        })
      )

      const data: GameAction = {
        userId: 'user-1',
        region: 'EU',
        matchId: 'match-1',
        amount: 0
      }

      try {
        await api.sendHeartbeat(data)
      } catch (error: any) {
        expect(error.response.status).toBe(429)
      }
    })
  })
})

describe('types', () => {
  it('GameAction has correct shape', () => {
    const action: GameAction = {
      userId: 'user-1',
      region: 'EU',
      matchId: 'match-1',
      amount: 1
    }

    expect(action.userId).toBe('user-1')
    expect(action.region).toBe('EU')
    expect(action.matchId).toBe('match-1')
    expect(action.amount).toBe(1)
  })

  it('GameAction can have optional fields', () => {
    const action: GameAction = {
      userId: 'user-1',
      region: 'EU',
      matchId: 'match-1',
      action: 'HEARTBEAT',
      amount: 0,
      timestamp: 123456789
    }

    expect(action.action).toBe('HEARTBEAT')
    expect(action.timestamp).toBe(123456789)
  })

  it('LeaderboardEntry has correct shape', () => {
    const entry: LeaderboardEntry = {
      userId: 'champion',
      score: 100,
      rank: 1
    }

    expect(entry.userId).toBe('champion')
    expect(entry.score).toBe(100)
    expect(entry.rank).toBe(1)
  })
})
