import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { server } from '../test/mocks/server'
import { errorHandlers } from '../test/mocks/handlers'
import Simulator from './Simulator'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

describe('Simulator', () => {
  it('renders the component title', () => {
    render(<Simulator />)
    expect(screen.getByText('Event Simulator')).toBeInTheDocument()
  })

  it('renders User ID input', () => {
    render(<Simulator />)
    expect(screen.getByLabelText('User ID')).toBeInTheDocument()
  })

  it('renders Region selector', () => {
    render(<Simulator />)
    expect(screen.getByLabelText('Region')).toBeInTheDocument()
  })

  it('renders Match ID selector', () => {
    render(<Simulator />)
    expect(screen.getByLabelText('Match ID')).toBeInTheDocument()
  })

  it('renders Drink Amount input', () => {
    render(<Simulator />)
    expect(screen.getByLabelText('Drink Amount')).toBeInTheDocument()
  })

  it('renders Send Heartbeat button', () => {
    render(<Simulator />)
    expect(screen.getByText('Send Heartbeat')).toBeInTheDocument()
  })

  it('renders Send Drink button', () => {
    render(<Simulator />)
    expect(screen.getByText('Send Drink')).toBeInTheDocument()
  })

  it('has default user-1 as User ID', () => {
    render(<Simulator />)
    const input = screen.getByLabelText('User ID') as HTMLInputElement
    expect(input.value).toBe('user-1')
  })

  it('has EU as default region', () => {
    render(<Simulator />)
    const select = screen.getByLabelText('Region') as HTMLSelectElement
    expect(select.value).toBe('EU')
  })

  it('has match-1 as default match', () => {
    render(<Simulator />)
    const select = screen.getByLabelText('Match ID') as HTMLSelectElement
    expect(select.value).toBe('match-1')
  })

  it('has 1 as default drink amount', () => {
    render(<Simulator />)
    const input = screen.getByLabelText('Drink Amount') as HTMLInputElement
    expect(input.value).toBe('1')
  })

  it('allows changing User ID', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const input = screen.getByLabelText('User ID')
    await user.clear(input)
    await user.type(input, 'test-user')

    expect(input).toHaveValue('test-user')
  })

  it('allows changing region', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const select = screen.getByLabelText('Region')
    await user.selectOptions(select, 'NA')

    expect(select).toHaveValue('NA')
  })

  it('has three region options', () => {
    render(<Simulator />)
    const select = screen.getByLabelText('Region')
    const options = select.querySelectorAll('option')

    expect(options).toHaveLength(3)
    expect(options[0]).toHaveValue('EU')
    expect(options[1]).toHaveValue('NA')
    expect(options[2]).toHaveValue('APAC')
  })

  it('allows changing drink amount', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const input = screen.getByLabelText('Drink Amount')
    await user.clear(input)
    await user.type(input, '5')

    expect(input).toHaveValue(5)
  })

  it('sends heartbeat and shows success message', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Heartbeat')
    await user.click(button)

    await waitFor(() => {
      expect(screen.getByText(/Heartbeat sent/)).toBeInTheDocument()
    })
  })

  it('sends drink and shows success message', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Drink')
    await user.click(button)

    await waitFor(() => {
      expect(screen.getByText(/Drink event sent/)).toBeInTheDocument()
    })
  })

  it('shows drink amount in success message', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const amountInput = screen.getByLabelText('Drink Amount')
    await user.clear(amountInput)
    await user.type(amountInput, '3')

    const button = screen.getByText('Send Drink')
    await user.click(button)

    await waitFor(() => {
      expect(screen.getByText(/Drink event sent \(3\)/)).toBeInTheDocument()
    })
  })

  it('shows error message on heartbeat failure', async () => {
    server.use(errorHandlers.heartbeatRateLimit)
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Heartbeat')
    await user.click(button)

    await waitFor(() => {
      expect(screen.getByText(/Error/)).toBeInTheDocument()
    })
  })

  it('shows error message on drink failure', async () => {
    server.use(errorHandlers.drinkError)
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Drink')
    await user.click(button)

    await waitFor(() => {
      expect(screen.getByText(/Error/)).toBeInTheDocument()
    })
  })

  it('success message has green styling', async () => {
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Heartbeat')
    await user.click(button)

    await waitFor(() => {
      const statusMessage = screen.getByText(/Heartbeat sent/)
      expect(statusMessage).toHaveClass('text-green-600')
    })
  })

  it('error message has red styling', async () => {
    server.use(errorHandlers.drinkError)
    const user = userEvent.setup()
    render(<Simulator />)

    const button = screen.getByText('Send Drink')
    await user.click(button)

    await waitFor(() => {
      const statusMessage = screen.getByText(/Error/)
      expect(statusMessage).toHaveClass('text-red-600')
    })
  })

  it('heartbeat button has blue styling', () => {
    render(<Simulator />)
    const button = screen.getByText('Send Heartbeat')
    expect(button).toHaveClass('bg-blue-500')
  })

  it('drink button has green styling', () => {
    render(<Simulator />)
    const button = screen.getByText('Send Drink')
    expect(button).toHaveClass('bg-green-500')
  })

  it('has correct card styling', () => {
    render(<Simulator />)
    const card = document.querySelector('.bg-white.rounded-lg.shadow')
    expect(card).toBeInTheDocument()
  })

  it('drink amount input has min value of 1', () => {
    render(<Simulator />)
    const input = screen.getByLabelText('Drink Amount')
    expect(input).toHaveAttribute('min', '1')
  })
})
