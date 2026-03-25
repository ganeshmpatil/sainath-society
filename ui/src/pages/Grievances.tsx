import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Search, Plus, AlertCircle, Clock, CheckCircle, XCircle, MessageSquare } from 'lucide-react'
import { grievances } from '../data/mockData'

const statusConfig: Record<string, { color: string; icon: React.ElementType; key: string }> = {
  'Open': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: AlertCircle, key: 'grievances.open' },
  'In Progress': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30', icon: Clock, key: 'grievances.inProgress' },
  'Resolved': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', icon: CheckCircle, key: 'grievances.resolved' },
  'Closed': { color: 'bg-slate-500/20 text-slate-400 border-slate-500/30', icon: XCircle, key: 'grievances.closed' },
}

const priorityConfig: Record<string, string> = {
  'Critical': 'bg-red-500 animate-pulse',
  'High': 'bg-orange-500',
  'Medium': 'bg-yellow-500',
  'Low': 'bg-emerald-500',
}

export default function Grievances() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [filterStatus, setFilterStatus] = useState('All')
  const [showModal, setShowModal] = useState(false)

  const filteredGrievances = grievances.filter(g => {
    const matchesSearch = g.subject.toLowerCase().includes(searchTerm.toLowerCase()) ||
      g.flat.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = filterStatus === 'All' || g.status === filterStatus
    return matchesSearch && matchesStatus
  })

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <MessageSquare className="w-6 h-6 text-orange-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('grievances.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('grievances.manageComplaints')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('grievances.newGrievance')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {Object.entries(statusConfig).map(([status, config]) => {
          const count = grievances.filter(g => g.status === status).length
          const Icon = config.icon
          return (
            <div key={status} className="stat-card">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-3xl font-bold text-white font-display">{count}</p>
                  <p className="text-sm text-slate-400">{t(config.key)}</p>
                </div>
                <div className={`p-3 rounded-xl border ${config.color}`}>
                  <Icon size={20} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Filters */}
      <div className="glass-card p-5 mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
            <input
              type="text"
              placeholder={t('grievances.searchPlaceholder')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-cyber pl-12"
            />
          </div>
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="input-cyber"
          >
            <option value="All">{t('grievances.allStatus')}</option>
            {Object.entries(statusConfig).map(([status, config]) => (
              <option key={status} value={status}>{t(config.key)}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Grievance List */}
      <div className="space-y-4">
        {filteredGrievances.map((grievance) => (
          <div key={grievance.id} className="glass-card-hover p-6">
            <div className="flex items-start gap-4">
              <div className={`w-3 h-3 rounded-full mt-2 ${priorityConfig[grievance.priority]}`} />
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-3 mb-3">
                  <h3 className="font-semibold text-white text-lg">{grievance.subject}</h3>
                  <span className={`px-3 py-1 text-xs rounded-lg border ${statusConfig[grievance.status]?.color}`}>
                    {t(statusConfig[grievance.status]?.key || grievance.status)}
                  </span>
                  <span className="px-3 py-1 text-xs bg-slate-700/50 text-slate-300 rounded-lg border border-slate-600/30">
                    {t(`grievances.${grievance.priority.toLowerCase()}`)}
                  </span>
                </div>
                <p className="text-sm text-slate-400 mb-4">{grievance.description}</p>
                <div className="flex flex-wrap gap-6 text-sm text-slate-500">
                  <span>{t('residents.flat')}: <span className="text-purple-400">{grievance.flat}</span></span>
                  <span>{t('grievances.assignedTo')}: <span className="text-cyan-400">{grievance.assignedTo}</span></span>
                  <span>{t('grievances.created')}: <span className="text-slate-400">{grievance.createdAt}</span></span>
                </div>
              </div>
              <div className="flex gap-2">
                <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                  {t('common.view')}
                </button>
                <button className="px-4 py-2 text-sm font-medium text-cyan-400 bg-cyan-500/10 border border-cyan-500/30 rounded-xl hover:bg-cyan-500/20 transition-all">
                  {t('grievances.update')}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('grievances.newGrievance')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('grievances.subject')}</label>
                <input type="text" className="input-cyber" placeholder={t('grievances.subjectPlaceholder')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('grievances.description')}</label>
                <textarea rows={4} className="input-cyber" placeholder={t('grievances.descriptionPlaceholder')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('grievances.priority')}</label>
                  <select className="input-cyber">
                    <option value="Low">{t('grievances.low')}</option>
                    <option value="Medium">{t('grievances.medium')}</option>
                    <option value="High">{t('grievances.high')}</option>
                    <option value="Critical">{t('grievances.critical')}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('grievances.category')}</label>
                  <select className="input-cyber">
                    <option value="Maintenance">{t('grievances.maintenance')}</option>
                    <option value="Security">{t('grievances.security')}</option>
                    <option value="Parking">{t('grievances.parking')}</option>
                    <option value="Noise">{t('grievances.noise')}</option>
                    <option value="Other">{t('grievances.other')}</option>
                  </select>
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('common.submit')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
