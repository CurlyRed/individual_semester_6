import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { server } from './test/mocks/server'
import App from './App'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('App', () => {
  it('renders the main title', () => {
    render(<App />)
    expect(screen.getByText('World Cup Drinking Platform - Dashboard')).toBeInTheDocument()
  })

  it('renders HealthCard component', () => {
    render(<App />)
    expect(screen.getByText('Service Health')).toBeInTheDocument()
  })

  it('renders PresenceCard component', () => {
    render(<App />)
    expect(screen.getByText('Online Users')).toBeInTheDocument()
  })

  it('renders Leaderboard component', () => {
    render(<App />)
    expect(screen.getByText('Leaderboard')).toBeInTheDocument()
  })

  it('renders Simulator component', () => {
    render(<App />)
    expect(screen.getByText('Event Simulator')).toBeInTheDocument()
  })

  it('has correct page background color', () => {
    render(<App />)
    const mainDiv = document.querySelector('.bg-gray-100')
    expect(mainDiv).toBeInTheDocument()
  })

  it('has responsive grid layout', () => {
    render(<App />)
    const gridContainer = document.querySelector('.grid.grid-cols-1')
    expect(gridContainer).toBeInTheDocument()
  })

  it('has max width container', () => {
    render(<App />)
    const container = document.querySelector('.max-w-7xl')
    expect(container).toBeInTheDocument()
  })

  it('has padding', () => {
    render(<App />)
    const paddedDiv = document.querySelector('.py-8.px-4')
    expect(paddedDiv).toBeInTheDocument()
  })

  it('title has correct styling', () => {
    render(<App />)
    const title = screen.getByText('World Cup Drinking Platform - Dashboard')
    expect(title).toHaveClass('text-4xl', 'font-bold', 'text-gray-900')
  })

  it('renders all four main components', () => {
    render(<App />)

    // Check all component titles are present
    expect(screen.getByText('Service Health')).toBeInTheDocument()
    expect(screen.getByText('Online Users')).toBeInTheDocument()
    expect(screen.getByText('Leaderboard')).toBeInTheDocument()
    expect(screen.getByText('Event Simulator')).toBeInTheDocument()
  })

  it('has minimum screen height', () => {
    render(<App />)
    const minHeightDiv = document.querySelector('.min-h-screen')
    expect(minHeightDiv).toBeInTheDocument()
  })
})
