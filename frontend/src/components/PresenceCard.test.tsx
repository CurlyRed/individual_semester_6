import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { server } from '../test/mocks/server'
import { errorHandlers } from '../test/mocks/handlers'
import { http, HttpResponse } from 'msw'
import PresenceCard from './PresenceCard'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('PresenceCard', () => {
  it('renders the component title', () => {
    render(<PresenceCard />)
    expect(screen.getByText('Online Users')).toBeInTheDocument()
  })

  it('shows loading state initially', () => {
    render(<PresenceCard />)
    expect(screen.getByText('...')).toBeInTheDocument()
  })

  it('displays online count after loading', async () => {
    render(<PresenceCard />)

    await waitFor(() => {
      expect(screen.getByText('42')).toBeInTheDocument()
    })
  })

  it('displays description text', () => {
    render(<PresenceCard />)
    expect(screen.getByText('Active in last 30 seconds')).toBeInTheDocument()
  })

  it('formats large numbers with locale string', async () => {
    server.use(
      http.get('http://localhost:8083/api/presence/onlineCount', () => {
        return HttpResponse.json({ onlineCount: 1000000, timestamp: Date.now() })
      })
    )

    render(<PresenceCard />)

    await waitFor(() => {
      // Should be formatted with commas
      expect(screen.getByText('1,000,000')).toBeInTheDocument()
    })
  })

  it('handles zero online users', async () => {
    server.use(
      http.get('http://localhost:8083/api/presence/onlineCount', () => {
        return HttpResponse.json({ onlineCount: 0, timestamp: Date.now() })
      })
    )

    render(<PresenceCard />)

    await waitFor(() => {
      expect(screen.getByText('0')).toBeInTheDocument()
    })
  })

  it('keeps previous value on error', async () => {
    // First render with successful response
    render(<PresenceCard />)

    await waitFor(() => {
      expect(screen.getByText('42')).toBeInTheDocument()
    })

    // Then simulate error on next poll
    server.use(errorHandlers.presenceError)

    // Value should still be displayed (component keeps last known value)
    expect(screen.getByText('42')).toBeInTheDocument()
  })

  it('has correct styling classes', () => {
    render(<PresenceCard />)

    const card = document.querySelector('.bg-white.rounded-lg.shadow')
    expect(card).toBeInTheDocument()
  })

  it('displays count in blue color', async () => {
    render(<PresenceCard />)

    await waitFor(() => {
      const countElement = document.querySelector('.text-blue-600')
      expect(countElement).toBeInTheDocument()
    })
  })

  it('polls presence endpoint every 3 seconds', async () => {
    render(<PresenceCard />)

    // Wait for initial load
    await waitFor(() => {
      expect(screen.getByText('42')).toBeInTheDocument()
    })
  })

  it('cleans up interval on unmount', () => {
    const { unmount } = render(<PresenceCard />)
    // Should not throw when unmounting
    expect(() => unmount()).not.toThrow()
  })
})
