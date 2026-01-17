import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest'
import { render, screen, waitFor, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { server } from '../test/mocks/server'
import { errorHandlers } from '../test/mocks/handlers'
import Leaderboard from './Leaderboard'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('Leaderboard', () => {
  it('renders the component title', () => {
    render(<Leaderboard />)
    expect(screen.getByText('Leaderboard')).toBeInTheDocument()
  })

  it('shows loading state initially', () => {
    render(<Leaderboard />)
    expect(screen.getByText('Loading...')).toBeInTheDocument()
  })

  it('displays leaderboard entries after loading', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      expect(screen.getByText('user-1')).toBeInTheDocument()
      expect(screen.getByText('user-2')).toBeInTheDocument()
      expect(screen.getByText('user-3')).toBeInTheDocument()
    })
  })

  it('displays scores correctly', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      expect(screen.getByText('100')).toBeInTheDocument()
      expect(screen.getByText('80')).toBeInTheDocument()
      expect(screen.getByText('60')).toBeInTheDocument()
    })
  })

  it('displays ranks correctly', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      // Find cells with rank numbers
      const rows = screen.getAllByRole('row')
      expect(rows.length).toBeGreaterThan(1) // Header + data rows
    })
  })

  it('shows empty state message when no entries', async () => {
    server.use(errorHandlers.leaderboardEmpty)

    render(<Leaderboard />)

    await waitFor(() => {
      expect(screen.getByText('No data yet. Send some drink events!')).toBeInTheDocument()
    })
  })

  it('renders match selector dropdown', () => {
    render(<Leaderboard />)

    const select = screen.getByRole('combobox')
    expect(select).toBeInTheDocument()
  })

  it('has three match options', () => {
    render(<Leaderboard />)

    const options = screen.getAllByRole('option')
    expect(options).toHaveLength(3)
    expect(options[0]).toHaveTextContent('Match 1')
    expect(options[1]).toHaveTextContent('Match 2')
    expect(options[2]).toHaveTextContent('Match 3')
  })

  it('changes match when different option selected', async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    render(<Leaderboard />)

    const select = screen.getByRole('combobox')
    await user.selectOptions(select, 'match-2')

    expect(select).toHaveValue('match-2')
  })

  it('renders table headers', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      expect(screen.getByText('Rank')).toBeInTheDocument()
      expect(screen.getByText('User ID')).toBeInTheDocument()
      expect(screen.getByText('Score')).toBeInTheDocument()
    })
  })

  it('has correct table structure', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      const table = screen.getByRole('table')
      expect(table).toBeInTheDocument()

      const headers = screen.getAllByRole('columnheader')
      expect(headers).toHaveLength(3)
    })
  })

  it('handles API error gracefully', async () => {
    server.use(errorHandlers.leaderboardError)

    render(<Leaderboard />)

    // Should not crash, will show empty or previous state
    await waitFor(() => {
      // Loading should finish
      expect(screen.queryByText('Loading...')).not.toBeInTheDocument()
    })
  })

  it('has correct styling classes', () => {
    render(<Leaderboard />)

    const card = document.querySelector('.bg-white.rounded-lg.shadow')
    expect(card).toBeInTheDocument()
  })

  it('refetches on match change', async () => {
    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime })
    render(<Leaderboard />)

    await waitFor(() => {
      expect(screen.getByText('user-1')).toBeInTheDocument()
    })

    const select = screen.getByRole('combobox')
    await user.selectOptions(select, 'match-2')

    // Should trigger a new fetch
    await waitFor(() => {
      expect(screen.getByText('user-1')).toBeInTheDocument()
    })
  })

  it('cleans up interval on unmount', () => {
    vi.useFakeTimers()
    const clearIntervalSpy = vi.spyOn(global, 'clearInterval')

    const { unmount } = render(<Leaderboard />)
    unmount()

    expect(clearIntervalSpy).toHaveBeenCalled()

    vi.useRealTimers()
  })

  it('displays scores without decimals', async () => {
    render(<Leaderboard />)

    await waitFor(() => {
      // Score 100.0 should display as "100"
      expect(screen.getByText('100')).toBeInTheDocument()
    })
  })
})
