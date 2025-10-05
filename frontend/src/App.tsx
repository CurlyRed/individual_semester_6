import HealthCard from './components/HealthCard'
import PresenceCard from './components/PresenceCard'
import Leaderboard from './components/Leaderboard'
import Simulator from './components/Simulator'

function App() {
  return (
    <div className="min-h-screen bg-gray-100 py-8 px-4">
      <div className="max-w-7xl mx-auto">
        <h1 className="text-4xl font-bold text-gray-900 mb-8">
          World Cup Drinking Platform - Dashboard
        </h1>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-6">
          <HealthCard />
          <PresenceCard />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Leaderboard />
          <Simulator />
        </div>
      </div>
    </div>
  )
}

export default App
