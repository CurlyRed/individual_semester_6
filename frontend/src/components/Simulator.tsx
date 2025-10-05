import { useState } from 'react'
import { api } from '../lib/api'

export default function Simulator() {
  const [userId, setUserId] = useState('user-1')
  const [region, setRegion] = useState('EU')
  const [matchId, setMatchId] = useState('match-1')
  const [amount, setAmount] = useState(1)
  const [status, setStatus] = useState('')

  const sendHeartbeat = async () => {
    try {
      await api.sendHeartbeat({ userId, region, matchId, amount: 0 })
      setStatus('✓ Heartbeat sent')
      setTimeout(() => setStatus(''), 2000)
    } catch (error: any) {
      setStatus(`✗ Error: ${error.response?.data?.error || error.message}`)
    }
  }

  const sendDrink = async () => {
    try {
      await api.sendDrink({ userId, region, matchId, amount })
      setStatus(`✓ Drink event sent (${amount})`)
      setTimeout(() => setStatus(''), 2000)
    } catch (error: any) {
      setStatus(`✗ Error: ${error.response?.data?.error || error.message}`)
    }
  }

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-semibold text-gray-900 mb-4">Event Simulator</h2>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">User ID</label>
          <input
            type="text"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            className="w-full border border-gray-300 rounded px-3 py-2"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Region</label>
            <select
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              className="w-full border border-gray-300 rounded px-3 py-2"
            >
              <option value="EU">EU</option>
              <option value="NA">NA</option>
              <option value="APAC">APAC</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Match ID</label>
            <select
              value={matchId}
              onChange={(e) => setMatchId(e.target.value)}
              className="w-full border border-gray-300 rounded px-3 py-2"
            >
              <option value="match-1">Match 1</option>
              <option value="match-2">Match 2</option>
              <option value="match-3">Match 3</option>
            </select>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Drink Amount</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(parseInt(e.target.value))}
            min="1"
            className="w-full border border-gray-300 rounded px-3 py-2"
          />
        </div>

        <div className="flex gap-2">
          <button
            onClick={sendHeartbeat}
            className="flex-1 bg-blue-500 hover:bg-blue-600 text-white font-medium py-2 px-4 rounded"
          >
            Send Heartbeat
          </button>
          <button
            onClick={sendDrink}
            className="flex-1 bg-green-500 hover:bg-green-600 text-white font-medium py-2 px-4 rounded"
          >
            Send Drink
          </button>
        </div>

        {status && (
          <div className={`text-sm font-medium ${status.startsWith('✓') ? 'text-green-600' : 'text-red-600'}`}>
            {status}
          </div>
        )}
      </div>
    </div>
  )
}
