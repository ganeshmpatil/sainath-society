import { Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Login from './pages/Login'
import Register from './pages/Register'
import Dashboard from './pages/Dashboard'
import Layout from './components/Layout'
import GalaxyBackground from './components/GalaxyBackground'
import ResidentDirectory from './pages/ResidentDirectory'
import FlatDetails from './pages/FlatDetails'
import Grievances from './pages/Grievances'
import Notices from './pages/Notices'
import Decisions from './pages/Decisions'
import Suggestions from './pages/Suggestions'
import Finance from './pages/Finance'
import Vehicles from './pages/Vehicles'
import Polls from './pages/Polls'
import Meetings from './pages/Meetings'
import PendingTasks from './pages/PendingTasks'
import Inventory from './pages/Inventory'
import HallBooking from './pages/HallBooking'
import MoveInOut from './pages/MoveInOut'
import Bylaws from './pages/Bylaws'
import { Loader2 } from 'lucide-react'

// Loading screen component
function LoadingScreen() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950">
      <div className="text-center">
        <Loader2 className="w-12 h-12 text-purple-500 animate-spin mx-auto mb-4" />
        <p className="text-slate-400">Loading...</p>
      </div>
    </div>
  )
}

// Protected route wrapper
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth()

  if (isLoading) {
    return <LoadingScreen />
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}

// Admin-only route wrapper
function AdminRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isAdmin, isLoading } = useAuth()

  if (isLoading) {
    return <LoadingScreen />
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />
  }

  if (!isAdmin) {
    return <Navigate to="/" replace />
  }

  return <>{children}</>
}

// Main App content (uses auth context)
function AppContent() {
  const { isAuthenticated, isLoading, user, logout } = useAuth()

  if (isLoading) {
    return <LoadingScreen />
  }

  if (!isAuthenticated) {
    return (
      <>
        <GalaxyBackground />
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </>
    )
  }

  return (
    <>
      <GalaxyBackground />
      <Layout user={user} onLogout={logout}>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/residents" element={<ResidentDirectory />} />
          <Route path="/flats" element={<FlatDetails />} />
          <Route path="/grievances" element={<Grievances />} />
          <Route path="/notices" element={<Notices />} />
          <Route path="/decisions" element={<Decisions />} />
          <Route path="/suggestions" element={<Suggestions />} />
          <Route path="/finance" element={<Finance />} />
          <Route path="/vehicles" element={<Vehicles />} />
          <Route path="/polls" element={<Polls />} />
          <Route path="/meetings" element={<Meetings />} />
          <Route
            path="/tasks"
            element={
              <AdminRoute>
                <PendingTasks />
              </AdminRoute>
            }
          />
          <Route path="/inventory" element={<Inventory />} />
          <Route path="/hall-booking" element={<HallBooking />} />
          <Route path="/move-in-out" element={<MoveInOut />} />
          <Route path="/bylaws" element={<Bylaws />} />
          <Route path="/login" element={<Navigate to="/" replace />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Layout>
    </>
  )
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
