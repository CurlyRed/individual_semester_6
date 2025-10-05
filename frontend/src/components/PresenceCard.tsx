import { useState, useEffect } from 'react'
import { api } from '../lib/api'

export default function PresenceCard() {
  const [onlineCount, setOnlineCount] = useState(0)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchPresence = async () => {
      try {
        const response = await api.getOnlineCount()
        setOnlineCount(response.data.onlineCount)
      } catch (error) {
        console.error('Failed to fetch online count:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchPresence()
    const interval = setInterval(fetchPresence, 3000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold text-gray-900 mb-4">Online Users</h2>
      <div className="flex items-center">
        <span className="text-4xl font-bold text-blue-600">
          {loading ? '...' : onlineCount.toLocaleString()}
        </span>
      </div>
      <p className="text-sm text-gray-500 mt-2">Active in last 30 seconds</p>
    </div>
  )
}
