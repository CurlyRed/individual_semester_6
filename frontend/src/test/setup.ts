import '@testing-library/jest-dom'
import { afterEach, vi } from 'vitest'
import { cleanup } from '@testing-library/react'

// Cleanup after each test
afterEach(() => {
  cleanup()
})

// Mock import.meta.env
vi.stubGlobal('import.meta', {
  env: {
    PROD: false,
    VITE_API_KEY: 'test-api-key'
  }
})
