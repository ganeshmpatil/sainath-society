import { useTranslation } from 'react-i18next'
import {
  Users, Building2, AlertCircle, Bell, DollarSign, Calendar,
  CheckSquare, TrendingUp, TrendingDown, Activity, Zap
} from 'lucide-react'
import { residents, grievances, notices, financials, pendingTasks, meetings } from '../data/mockData'

interface StatCardProps {
  icon: React.ElementType
  label: string
  value: string | number
  subtext?: string
  gradient: string
  trend?: number
  trendLabel?: string
}

const StatCard = ({ icon: Icon, label, value, subtext, gradient, trend, trendLabel }: StatCardProps) => (
  <div className="stat-card group">
    <div className="flex items-start justify-between">
      <div>
        <p className="text-sm font-medium text-slate-400 uppercase tracking-wider">{label}</p>
        <p className="text-3xl font-bold text-white mt-2 font-display">{value}</p>
        {subtext && <p className="text-xs text-slate-500 mt-1">{subtext}</p>}
      </div>
      <div className={`p-3 rounded-xl ${gradient} group-hover:scale-110 transition-transform duration-300`}>
        <Icon className="w-6 h-6 text-white" />
      </div>
    </div>
    {trend && (
      <div className={`flex items-center gap-1 mt-4 text-sm ${trend > 0 ? 'text-emerald-400' : 'text-red-400'}`}>
        {trend > 0 ? <TrendingUp size={16} /> : <TrendingDown size={16} />}
        <span>{Math.abs(trend)}% {trendLabel}</span>
      </div>
    )}
  </div>
)

export default function Dashboard() {
  const { t } = useTranslation()
  const openGrievances = grievances.filter(g => g.status !== 'Resolved').length
  const highPriorityTasks = pendingTasks.filter(t => t.priority === 'High').length

  return (
    <div>
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Activity className="w-6 h-6 text-purple-400" />
          <h1 className="font-display text-3xl font-bold gradient-text">{t('dashboard.title').toUpperCase()}</h1>
        </div>
        <p className="text-slate-400">{t('dashboard.welcome')}! {t('dashboard.overview')}</p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        <StatCard
          icon={Users}
          label={t('dashboard.totalMembers')}
          value={residents.length}
          subtext={t('flats.wing') + ' A, B, C'}
          gradient="bg-gradient-to-br from-blue-500 to-blue-600"
        />
        <StatCard
          icon={Building2}
          label={t('flats.title')}
          value="72"
          subtext={t('flats.wing') + ' A, B, C'}
          gradient="bg-gradient-to-br from-purple-500 to-purple-600"
        />
        <StatCard
          icon={AlertCircle}
          label={t('dashboard.activeGrievances')}
          value={openGrievances}
          subtext={t('grievances.open')}
          gradient="bg-gradient-to-br from-orange-500 to-red-500"
        />
        <StatCard
          icon={DollarSign}
          label={t('dashboard.totalCollection')}
          value={`₹${(financials.summary.totalCollection / 100000).toFixed(1)}L`}
          subtext={`${t('dashboard.pendingAmount')}: ₹${(financials.summary.pendingDues / 1000).toFixed(0)}K`}
          gradient="bg-gradient-to-br from-emerald-500 to-emerald-600"
          trend={5}
          trendLabel={t('dashboard.lastMonth')}
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Notices */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <Bell className="w-5 h-5 text-cyan-400" />
              {t('dashboard.notices')}
            </h2>
            <span className="badge-cyber">{notices.length} {t('common.all')}</span>
          </div>
          <div className="space-y-3">
            {notices.slice(0, 4).map((notice) => (
              <div key={notice.id} className="p-4 rounded-xl bg-slate-800/50 border-l-2 border-cyan-500 hover:bg-slate-800 transition-colors cursor-pointer">
                <p className="font-medium text-white text-sm">{notice.title}</p>
                <p className="text-xs text-slate-500 mt-1">{notice.date}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Recent Grievances */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <AlertCircle className="w-5 h-5 text-orange-400" />
              {t('dashboard.activeGrievances')}
            </h2>
            <span className="badge-cyber">{openGrievances} {t('grievances.open')}</span>
          </div>
          <div className="space-y-3">
            {grievances.slice(0, 4).map((grievance) => (
              <div key={grievance.id} className="flex items-start gap-3 p-4 rounded-xl bg-slate-800/50 hover:bg-slate-800 transition-colors cursor-pointer">
                <span className={`w-2 h-2 rounded-full mt-2 ${
                  grievance.priority === 'Critical' ? 'bg-red-500 animate-pulse' :
                  grievance.priority === 'High' ? 'bg-orange-500' :
                  grievance.priority === 'Medium' ? 'bg-yellow-500' : 'bg-green-500'
                }`} />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{grievance.subject}</p>
                  <p className="text-xs text-slate-500">{grievance.flat} • {grievance.status}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Upcoming Events */}
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <Calendar className="w-5 h-5 text-purple-400" />
              {t('dashboard.upcomingMeetings')}
            </h2>
          </div>
          <div className="space-y-3">
            {meetings.filter(m => m.status === 'Scheduled').map((meeting) => (
              <div key={meeting.id} className="p-4 rounded-xl bg-gradient-to-r from-purple-500/10 to-cyan-500/10 border border-purple-500/20">
                <div className="flex items-center gap-2 mb-2">
                  <span className="px-2 py-0.5 text-xs font-semibold bg-purple-500/20 text-purple-400 rounded border border-purple-500/30">
                    {meeting.type}
                  </span>
                </div>
                <p className="font-medium text-white text-sm">{meeting.title}</p>
                <p className="text-xs text-slate-400 mt-1">{meeting.date} at {meeting.time}</p>
              </div>
            ))}
            <div className="p-4 rounded-xl bg-gradient-to-r from-orange-500/10 to-red-500/10 border border-orange-500/20">
              <div className="flex items-center gap-2 mb-2">
                <CheckSquare className="w-4 h-4 text-orange-400" />
                <span className="text-xs font-semibold text-orange-400">{highPriorityTasks} {t('tasks.title')}</span>
              </div>
              <p className="text-xs text-slate-400">{t('dashboard.pendingPayments')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Financial Summary */}
      <div className="mt-8 glass-card p-6">
        <div className="flex items-center gap-3 mb-6">
          <Zap className="w-5 h-5 text-emerald-400" />
          <h2 className="text-lg font-semibold text-white">{t('finance.title')} {t('dashboard.overview')}</h2>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-emerald-500/10 to-emerald-600/10 border border-emerald-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('dashboard.totalCollection')}</p>
            <p className="text-2xl font-bold text-emerald-400 mt-2 font-display">₹{(financials.summary.totalCollection / 100000).toFixed(1)}L</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-red-500/10 to-red-600/10 border border-red-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('dashboard.pendingAmount')}</p>
            <p className="text-2xl font-bold text-red-400 mt-2 font-display">₹{(financials.summary.pendingDues / 1000).toFixed(0)}K</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-blue-500/10 to-blue-600/10 border border-blue-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('finance.expenses')}</p>
            <p className="text-2xl font-bold text-blue-400 mt-2 font-display">₹{(financials.summary.totalExpenses / 100000).toFixed(1)}L</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-cyan-500/10 to-cyan-600/10 border border-cyan-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('finance.balance')}</p>
            <p className="text-2xl font-bold text-cyan-400 mt-2 font-display">₹{(financials.summary.balance / 100000).toFixed(1)}L</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-purple-500/10 to-purple-600/10 border border-purple-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('finance.corpus')}</p>
            <p className="text-2xl font-bold text-purple-400 mt-2 font-display">₹{(financials.summary.corpusFund / 100000).toFixed(1)}L</p>
          </div>
        </div>
      </div>
    </div>
  )
}
