import { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Home, Users, Building2, MessageSquare, Bell, FileText,
  Lightbulb, DollarSign, Car, Vote, Calendar, CheckSquare,
  Package, CalendarDays, ArrowLeftRight, BookOpen, Menu, X, LogOut, User
} from 'lucide-react'
import LanguageSelector from './LanguageSelector'

interface UserInfo {
  name?: string
  flat?: string
  role?: string
  isAdmin?: boolean
}

interface LayoutProps {
  children: React.ReactNode
  user: UserInfo | null
  onLogout: () => void
}

const menuItems = [
  { path: '/', icon: Home, labelKey: 'sidebar.dashboard' },
  { path: '/residents', icon: Users, labelKey: 'sidebar.residents' },
  { path: '/flats', icon: Building2, labelKey: 'sidebar.flats' },
  { path: '/bylaws', icon: BookOpen, labelKey: 'sidebar.bylaws' },
  { path: '/grievances', icon: MessageSquare, labelKey: 'sidebar.grievances' },
  { path: '/notices', icon: Bell, labelKey: 'sidebar.notices' },
  { path: '/decisions', icon: FileText, labelKey: 'sidebar.decisions' },
  { path: '/suggestions', icon: Lightbulb, labelKey: 'sidebar.suggestions' },
  { path: '/finance', icon: DollarSign, labelKey: 'sidebar.finance' },
  { path: '/vehicles', icon: Car, labelKey: 'sidebar.vehicles' },
  { path: '/polls', icon: Vote, labelKey: 'sidebar.polls' },
  { path: '/meetings', icon: Calendar, labelKey: 'sidebar.meetings' },
  { path: '/tasks', icon: CheckSquare, labelKey: 'sidebar.tasks' },
  { path: '/inventory', icon: Package, labelKey: 'sidebar.inventory' },
  { path: '/hall-booking', icon: CalendarDays, labelKey: 'sidebar.hallBooking' },
  { path: '/move-in-out', icon: ArrowLeftRight, labelKey: 'sidebar.moveInOut' },
]

export default function Layout({ children, user, onLogout }: LayoutProps) {
  const { t } = useTranslation()
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const location = useLocation()

  return (
    <div className="min-h-screen">
      {/* Mobile sidebar backdrop */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/70 backdrop-blur-sm z-20 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside className={`fixed top-0 left-0 z-30 h-full w-72 transform transition-transform duration-300 ease-out lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="h-full bg-slate-900/90 backdrop-blur-xl border-r border-purple-500/20">
          {/* Logo */}
          <div className="flex items-center justify-between h-20 px-6 border-b border-purple-500/20">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-white/10 overflow-hidden border border-purple-500/30">
                <img src="/sai.jpg" alt="Logo" className="w-full h-full object-cover" />
              </div>
              <div>
                <h1 className="font-display text-lg font-bold gradient-text">{t('app.name')}</h1>
                <p className="text-[10px] text-slate-400 tracking-widest uppercase">{t('app.tagline')}</p>
              </div>
            </div>
            <button onClick={() => setSidebarOpen(false)} className="lg:hidden text-slate-400 hover:text-white">
              <X size={24} />
            </button>
          </div>

          {/* Navigation */}
          <nav className="mt-6 px-3 overflow-y-auto h-[calc(100vh-12rem)]">
            {menuItems.map((item) => {
              const Icon = item.icon
              const isActive = location.pathname === item.path
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setSidebarOpen(false)}
                  className={`group flex items-center gap-3 px-4 py-3 mb-1 rounded-xl transition-all duration-300 relative overflow-hidden ${
                    isActive
                      ? 'bg-gradient-to-r from-purple-500/20 to-cyan-500/20 text-white border border-purple-500/30'
                      : 'text-slate-400 hover:text-white hover:bg-white/5'
                  }`}
                >
                  {isActive && (
                    <div className="absolute left-0 top-0 w-1 h-full bg-gradient-to-b from-purple-500 to-cyan-500 rounded-r" />
                  )}
                  <Icon size={18} className={isActive ? 'text-purple-400' : 'group-hover:text-purple-400 transition-colors'} />
                  <span className="text-sm font-medium tracking-wide">{t(item.labelKey)}</span>
                  {isActive && (
                    <div className="absolute right-3 w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
                  )}
                </Link>
              )
            })}
          </nav>

          {/* User Profile */}
          <div className="absolute bottom-0 left-0 right-0 p-4 border-t border-purple-500/20 bg-slate-900/50">
            <div className="flex items-center gap-3">
              <div className="relative">
                <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-purple-500 to-cyan-500 flex items-center justify-center">
                  <User size={20} className="text-white" />
                </div>
                <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-green-500 rounded-full border-2 border-slate-900" />
              </div>
              <div className="flex-1">
                <p className="text-sm font-semibold text-white">{user?.name}</p>
                <p className="text-xs text-purple-400">{user?.flat} • {user?.role}</p>
              </div>
              <button
                onClick={onLogout}
                className="p-2.5 rounded-xl bg-red-500/10 text-red-400 hover:bg-red-500/20 hover:text-red-300 transition-all"
                title={t('sidebar.logout')}
              >
                <LogOut size={18} />
              </button>
            </div>
          </div>
        </div>
      </aside>

      {/* Main content */}
      <div className="lg:ml-72">
        {/* Top bar */}
        <header className="sticky top-0 z-10 flex items-center h-20 px-6 bg-slate-900/60 backdrop-blur-xl border-b border-purple-500/10">
          <button
            onClick={() => setSidebarOpen(true)}
            className="p-2.5 rounded-xl bg-purple-500/10 text-purple-400 hover:bg-purple-500/20 lg:hidden"
          >
            <Menu size={24} />
          </button>

          <div className="ml-auto flex items-center gap-4">
            <LanguageSelector />
            <div className="hidden sm:flex items-center gap-2 px-4 py-2 rounded-xl bg-slate-800/50 border border-purple-500/20">
              <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
              <span className="text-sm text-slate-300">{t('common.systemOnline')}</span>
            </div>
            <span className="text-sm text-slate-400">{t('common.welcome')}, <span className="text-purple-400 font-semibold">{user?.name}</span></span>
            {user?.isAdmin && (
              <span className="px-3 py-1.5 text-xs font-bold rounded-lg bg-gradient-to-r from-purple-500/20 to-cyan-500/20 text-cyan-400 border border-cyan-500/30 uppercase tracking-wider">
                {t('login.admin')}
              </span>
            )}
          </div>
        </header>

        {/* Page content */}
        <main className="p-6 lg:p-8">
          {children}
        </main>
      </div>
    </div>
  )
}
