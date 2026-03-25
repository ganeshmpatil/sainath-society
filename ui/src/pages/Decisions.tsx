import { useTranslation } from 'react-i18next'
import { FileText, CheckCircle, Clock, XCircle, ThumbsUp, ThumbsDown, Gavel } from 'lucide-react'
import { decisions } from '../data/mockData'

const statusConfig = {
  'Implemented': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', icon: CheckCircle },
  'In Progress': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30', icon: Clock },
  'Pending': { color: 'bg-blue-500/20 text-blue-400 border-blue-500/30', icon: Clock },
  'Rejected': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: XCircle },
}

export default function Decisions() {
  const { t } = useTranslation()

  const getStatusText = (status: string) => {
    switch (status) {
      case 'Implemented': return t('suggestions.implemented')
      case 'In Progress': return t('grievances.inProgress')
      case 'Pending': return t('suggestions.pending')
      case 'Rejected': return t('suggestions.rejected')
      default: return status
    }
  }

  return (
    <div>
      <div className="mb-8">
        <div className="flex items-center gap-3 mb-2">
          <Gavel className="w-6 h-6 text-purple-400" />
          <h1 className="font-display text-3xl font-bold gradient-text">{t('decisions.title').toUpperCase()}</h1>
        </div>
        <p className="text-slate-400">{t('decisions.description', 'Record of all society decisions and resolutions')}</p>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div className="stat-card">
          <p className="text-3xl font-bold text-white font-display">{decisions.length}</p>
          <p className="text-sm text-slate-400">{t('decisions.totalDecisions', 'Total Decisions')}</p>
        </div>
        <div className="stat-card">
          <p className="text-3xl font-bold text-emerald-400 font-display">{decisions.filter(d => d.status === 'Implemented').length}</p>
          <p className="text-sm text-slate-400">{t('suggestions.implemented')}</p>
        </div>
        <div className="stat-card">
          <p className="text-3xl font-bold text-yellow-400 font-display">{decisions.filter(d => d.status === 'In Progress').length}</p>
          <p className="text-sm text-slate-400">{t('grievances.inProgress')}</p>
        </div>
        <div className="stat-card">
          <p className="text-3xl font-bold text-blue-400 font-display">{decisions.filter(d => d.status === 'Pending').length}</p>
          <p className="text-sm text-slate-400">{t('suggestions.pending')}</p>
        </div>
      </div>

      {/* Timeline */}
      <div className="glass-card p-6">
        <h2 className="text-lg font-semibold text-white mb-6 flex items-center gap-2">
          <FileText className="text-cyan-400" size={20} />
          {t('decisions.timeline', 'Decision Timeline')}
        </h2>
        <div className="space-y-6">
          {decisions.map((decision, index) => {
            const totalVotes = decision.votesFor + decision.votesAgainst
            const approvalRate = totalVotes > 0 ? Math.round((decision.votesFor / totalVotes) * 100) : 0

            return (
              <div key={decision.id} className="relative pl-10">
                {index !== decisions.length - 1 && (
                  <div className="absolute left-4 top-10 w-0.5 h-full bg-gradient-to-b from-purple-500 to-transparent" />
                )}
                <div className="absolute left-0 top-1 w-8 h-8 rounded-xl bg-gradient-to-br from-purple-500 to-cyan-500 flex items-center justify-center">
                  <FileText size={14} className="text-white" />
                </div>

                <div className="rounded-xl bg-slate-800/50 border border-slate-700/50 p-6 hover:border-purple-500/30 transition-colors">
                  <div className="flex flex-wrap items-center gap-3 mb-3">
                    <span className="px-3 py-1 text-xs font-semibold bg-purple-500/20 text-purple-400 rounded-lg border border-purple-500/30">
                      {decision.meetingType}
                    </span>
                    <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${statusConfig[decision.status as keyof typeof statusConfig]?.color}`}>
                      {getStatusText(decision.status)}
                    </span>
                    <span className="text-sm text-slate-500">{decision.date}</span>
                  </div>

                  <h3 className="font-bold text-white text-xl">{decision.title}</h3>
                  <p className="text-slate-400 mt-2">{decision.description}</p>

                  <div className="mt-5 flex flex-wrap items-center gap-6">
                    <div className="flex items-center gap-4">
                      <div className="flex items-center gap-2 text-emerald-400">
                        <ThumbsUp size={18} />
                        <span className="font-bold">{decision.votesFor}</span>
                      </div>
                      <div className="flex items-center gap-2 text-red-400">
                        <ThumbsDown size={18} />
                        <span className="font-bold">{decision.votesAgainst}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <div className="w-32 progress-cyber">
                        <div className="progress-cyber-fill" style={{ width: `${approvalRate}%` }} />
                      </div>
                      <span className="text-sm text-slate-400">{approvalRate}% {t('decisions.approved', 'approved')}</span>
                    </div>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
