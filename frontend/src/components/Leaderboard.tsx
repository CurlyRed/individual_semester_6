import { useState, useEffect } from 'react'
import { api, LeaderboardEntry } from '../lib/api'

export default function Leaderboard() {
  const [entries, setEntries] = useState<LeaderboardEntry[]>([])
  const [matchId, setMatchId] = useState('match-1')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchLeaderboard = async () => {
      try {
        const response = await api.getLeaderboard(matchId, 10)
        setEntries(response.data.entries)
      } catch (error) {
        console.error('Failed to fetch leaderboard:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchLeaderboard()
    const interval = setInterval(fetchLeaderboard, 5000)
    return () => clearInterval(interval)
  }, [matchId])

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-semibold text-gray-900">Leaderboard</h2>
        <select
          value={matchId}
          onChange={(e) => setMatchId(e.target.value)}
          className="border border-gray-300 rounded px-3 py-1"
        >
          <option value="match-1">Match 1</option>
          <option value="match-2">Match 2</option>
          <option value="match-3">Match 3</option>
        </select>
      </div>

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : entries.length === 0 ? (
        <p className="text-gray-500">No data yet. Send some drink events!</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead>
              <tr>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Rank</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">User ID</th>
                <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Score</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {entries.map((entry) => (
                <tr key={entry.userId} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{entry.rank}</td>
                  <td className="px-4 py-3 text-sm text-gray-700">{entry.userId}</td>
                  <td className="px-4 py-3 text-sm text-gray-700">{entry.score.toFixed(0)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
