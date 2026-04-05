import { useTranslation } from 'react-i18next'
import { Users, Building2, AlertCircle, Bell, DollarSign, Calendar, Activity, TrendingUp } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { residentsApi, grievancesApi, noticesApi, billsApi, eventsApi, flatsApi } from '../api/resources'

interface StatCardProps {
  icon: React.ElementType
  label: string
  value: string | number
  subtext?: string
  gradient: string
}

const StatCard = ({ icon: Icon, label, value, subtext, gradient }: StatCardProps) => (
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
  </div>
)

export default function Dashboard() {
  const { t, i18n } = useTranslation()
  const isMr = i18n.language === 'mr'

  const residents = useApi(() => residentsApi.list({ activeOnly: true }), [])
  const grievances = useApi(() => grievancesApi.list({ status: 'OPEN' }), [])
  const notices = useApi(() => noticesApi.list(), [])
  const dues = useApi(() => billsApi.pendingDues(), [])
  const events = useApi(() => eventsApi.listUpcoming(), [])
  const flats = useApi(() => flatsApi.list(), [])

  return (
    <div>
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Activity className="w-6 h-6 text-purple-400" />
          <h1 className="font-display text-3xl font-bold gradient-text">{t('dashboard.title').toUpperCase()}</h1>
        </div>
        <p className="text-slate-400">{t('dashboard.welcome')}! {t('dashboard.overview')}</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5 mb-8">
        <StatCard
          icon={Users}
          label={t('dashboard.totalMembers')}
          value={residents.loading ? '...' : residents.data?.count ?? 0}
          gradient="bg-gradient-to-br from-blue-500 to-blue-600"
        />
        <StatCard
          icon={Building2}
          label={t('dashboard.totalFlats')}
          value={flats.loading ? '...' : flats.data?.count ?? 0}
          gradient="bg-gradient-to-br from-purple-500 to-purple-600"
        />
        <StatCard
          icon={AlertCircle}
          label={t('dashboard.activeGrievances')}
          value={grievances.loading ? '...' : grievances.data?.count ?? 0}
          subtext={t('grievances.open')}
          gradient="bg-gradient-to-br from-orange-500 to-red-500"
        />
        <StatCard
          icon={DollarSign}
          label={t('dashboard.pendingAmount')}
          value={dues.loading ? '...' : `₹${((dues.data?.pendingAmount ?? 0) / 1000).toFixed(0)}K`}
          subtext={`${dues.data?.unpaidCount ?? 0} ${t('finance.pending')}`}
          gradient="bg-gradient-to-br from-emerald-500 to-emerald-600"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <Bell className="w-5 h-5 text-cyan-400" />
              {t('dashboard.notices')}
            </h2>
            <span className="badge-cyber">{notices.data?.count ?? 0}</span>
          </div>
          <div className="space-y-3">
            {(notices.data?.notices ?? []).slice(0, 4).map((n) => (
              <div key={n.id} className="p-4 rounded-xl bg-slate-800/50 border-l-2 border-cyan-500 hover:bg-slate-800 transition-colors cursor-pointer">
                <p className="font-medium text-white text-sm">{isMr && n.titleMr ? n.titleMr : n.title}</p>
                <p className="text-xs text-slate-500 mt-1">{new Date(n.createdAt).toLocaleDateString()}</p>
              </div>
            ))}
            {notices.data?.count === 0 && (
              <p className="text-xs text-slate-500 text-center py-4">{t('common.noRecords')}</p>
            )}
          </div>
        </div>

        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <AlertCircle className="w-5 h-5 text-orange-400" />
              {t('dashboard.activeGrievances')}
            </h2>
            <span className="badge-cyber">{grievances.data?.count ?? 0}</span>
          </div>
          <div className="space-y-3">
            {(grievances.data?.grievances ?? []).slice(0, 4).map((g) => (
              <div key={g.id} className="flex items-start gap-3 p-4 rounded-xl bg-slate-800/50 hover:bg-slate-800 transition-colors cursor-pointer">
                <span className={`w-2 h-2 rounded-full mt-2 ${
                  g.priority === 'URGENT' ? 'bg-red-500 animate-pulse' :
                  g.priority === 'HIGH' ? 'bg-orange-500' :
                  g.priority === 'MEDIUM' ? 'bg-yellow-500' : 'bg-green-500'
                }`} />
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-white truncate">{isMr && g.titleMr ? g.titleMr : g.title}</p>
                  <p className="text-xs text-slate-500">{g.ticketNo}</p>
                </div>
              </div>
            ))}
            {grievances.data?.count === 0 && (
              <p className="text-xs text-slate-500 text-center py-4">{t('common.noRecords')}</p>
            )}
          </div>
        </div>

        <div className="glass-card p-6">
          <div className="flex items-center justify-between mb-5">
            <h2 className="text-lg font-semibold text-white flex items-center gap-2">
              <Calendar className="w-5 h-5 text-purple-400" />
              {t('dashboard.upcomingEvents')}
            </h2>
          </div>
          <div className="space-y-3">
            {(events.data?.events ?? []).slice(0, 4).map((e) => (
              <div key={e.id} className="p-4 rounded-xl bg-gradient-to-r from-purple-500/10 to-cyan-500/10 border border-purple-500/20">
                <div className="flex items-center gap-2 mb-2">
                  <span className="px-2 py-0.5 text-xs font-semibold bg-purple-500/20 text-purple-400 rounded border border-purple-500/30">
                    {e.eventType}
                  </span>
                </div>
                <p className="font-medium text-white text-sm">{isMr && e.titleMr ? e.titleMr : e.title}</p>
                <p className="text-xs text-slate-400 mt-1">{new Date(e.startTime).toLocaleString()}</p>
              </div>
            ))}
            {events.data?.count === 0 && (
              <p className="text-xs text-slate-500 text-center py-4">{t('common.noRecords')}</p>
            )}
          </div>
        </div>
      </div>

      <div className="mt-8 glass-card p-6">
        <div className="flex items-center gap-3 mb-6">
          <TrendingUp className="w-5 h-5 text-emerald-400" />
          <h2 className="text-lg font-semibold text-white">{t('finance.title')} {t('dashboard.overview')}</h2>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-red-500/10 to-red-600/10 border border-red-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('finance.pendingDues')}</p>
            <p className="text-2xl font-bold text-red-400 mt-2 font-display">₹{((dues.data?.pendingAmount ?? 0) / 1000).toFixed(0)}K</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-orange-500/10 to-orange-600/10 border border-orange-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('finance.pending')}</p>
            <p className="text-2xl font-bold text-orange-400 mt-2 font-display">{dues.data?.unpaidCount ?? 0}</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-blue-500/10 to-blue-600/10 border border-blue-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('dashboard.totalMembers')}</p>
            <p className="text-2xl font-bold text-blue-400 mt-2 font-display">{residents.data?.count ?? 0}</p>
          </div>
          <div className="text-center p-5 rounded-xl bg-gradient-to-br from-purple-500/10 to-purple-600/10 border border-purple-500/20">
            <p className="text-sm text-slate-400 uppercase tracking-wider">{t('dashboard.totalFlats')}</p>
            <p className="text-2xl font-bold text-purple-400 mt-2 font-display">{flats.data?.count ?? 0}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
