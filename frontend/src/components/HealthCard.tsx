import { useState, useEffect } from 'react'
import { api } from '../lib/api'

export default function HealthCard() {
  const [status, setStatus] = useState<'UP' | 'DOWN'>('DOWN')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchHealth = async () => {
      try {
        const response = await api.getHealth()
        setStatus(response.data.status === 'UP' ? 'UP' : 'DOWN')
      } catch (error) {
        setStatus('DOWN')
      } finally {
        setLoading(false)
      }
    }

    fetchHealth()
    const interval = setInterval(fetchHealth, 5000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold text-gray-900 mb-4">Service Health</h2>
      <div className="flex items-center">
        <div className={`h-4 w-4 rounded-full mr-3 ${status === 'UP' ? 'bg-green-500' : 'bg-red-500'}`}></div>
        <span className="text-2xl font-bold text-gray-900">
          {loading ? 'Checking...' : status}
        </span>
      </div>
    </div>
  )
}
