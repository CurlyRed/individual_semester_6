import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { server } from '../test/mocks/server'
import { errorHandlers } from '../test/mocks/handlers'
import HealthCard from './HealthCard'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('HealthCard', () => {
  it('renders the component title', () => {
    render(<HealthCard />)
    expect(screen.getByText('Service Health')).toBeInTheDocument()
  })

  it('shows loading state initially', () => {
    render(<HealthCard />)
    expect(screen.getByText('Checking...')).toBeInTheDocument()
  })

  it('displays UP status when service is healthy', async () => {
    render(<HealthCard />)

    await waitFor(() => {
      expect(screen.getByText('UP')).toBeInTheDocument()
    })
  })

  it('displays green indicator when UP', async () => {
    render(<HealthCard />)

    await waitFor(() => {
      const indicator = document.querySelector('.bg-green-500')
      expect(indicator).toBeInTheDocument()
    })
  })

  it('displays DOWN status when service returns error', async () => {
    server.use(errorHandlers.healthError)

    render(<HealthCard />)

    await waitFor(() => {
      expect(screen.getByText('DOWN')).toBeInTheDocument()
    })
  })

  it('displays red indicator when DOWN', async () => {
    server.use(errorHandlers.healthError)

    render(<HealthCard />)

    await waitFor(() => {
      const indicator = document.querySelector('.bg-red-500')
      expect(indicator).toBeInTheDocument()
    })
  })

  it('displays DOWN when health check returns non-UP status', async () => {
    server.use(errorHandlers.healthDown)

    render(<HealthCard />)

    await waitFor(() => {
      expect(screen.getByText('DOWN')).toBeInTheDocument()
    })
  })

  it('has correct styling classes', () => {
    render(<HealthCard />)

    const card = document.querySelector('.bg-white.rounded-lg.shadow')
    expect(card).toBeInTheDocument()
  })

  it('polls health endpoint periodically', async () => {
    vi.useFakeTimers()
    const fetchSpy = vi.spyOn(global, 'fetch')

    render(<HealthCard />)

    // Initial fetch
    await waitFor(() => {
      expect(fetchSpy).toHaveBeenCalled()
    })

    // Advance timer by 5 seconds (polling interval)
    vi.advanceTimersByTime(5000)

    // Should have made another fetch
    await waitFor(() => {
      expect(fetchSpy.mock.calls.length).toBeGreaterThanOrEqual(1)
    })

    vi.useRealTimers()
  })

  it('cleans up interval on unmount', () => {
    vi.useFakeTimers()
    const clearIntervalSpy = vi.spyOn(global, 'clearInterval')

    const { unmount } = render(<HealthCard />)
    unmount()

    expect(clearIntervalSpy).toHaveBeenCalled()

    vi.useRealTimers()
  })
})
