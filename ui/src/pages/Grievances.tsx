import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { MessageSquare, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { grievancesApi, Grievance } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const PRIORITY_COLORS: Record<string, string> = {
  URGENT: 'bg-red-500/10 text-red-400 border-red-500/30',
  HIGH: 'bg-orange-500/10 text-orange-400 border-orange-500/30',
  MEDIUM: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
  LOW: 'bg-green-500/10 text-green-400 border-green-500/30',
}

const STATUS_COLORS: Record<string, string> = {
  OPEN: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
  IN_PROGRESS: 'bg-cyan-500/10 text-cyan-400 border-cyan-500/30',
  RESOLVED: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
  CLOSED: 'bg-slate-500/10 text-slate-400 border-slate-500/30',
  REJECTED: 'bg-red-500/10 text-red-400 border-red-500/30',
}

const CATEGORIES = ['MAINTENANCE', 'SECURITY', 'NOISE', 'PARKING', 'CLEANLINESS', 'WATER', 'ELECTRICITY', 'OTHER']
const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT']

export default function Grievances() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [statusFilter, setStatusFilter] = useState<string>('')
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ title: '', description: '', category: 'MAINTENANCE', priority: 'MEDIUM' })

  const { data, loading, error, reload } = useApi(
    () => grievancesApi.list(statusFilter ? { status: statusFilter } : undefined),
    [statusFilter]
  )

  const create = async () => {
    try {
      await grievancesApi.create(form as Partial<Grievance>)
      setModalOpen(false)
      setForm({ title: '', description: '', category: 'MAINTENANCE', priority: 'MEDIUM' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const updateStatus = async (g: Grievance, status: string) => {
    try {
      await grievancesApi.updateStatus(g.id, status)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('grievances.title')}
      subtitle={t('grievances.manageComplaints')}
      icon={MessageSquare}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('grievances.newGrievance')}
        </button>
      }
    >
      <div className="glass-card p-4 mb-4 flex items-center gap-3 flex-wrap">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="input-cyber"
        >
          <option value="">{t('grievances.allStatus')}</option>
          <option value="OPEN">{t('grievances.open')}</option>
          <option value="IN_PROGRESS">{t('grievances.inProgress')}</option>
          <option value="RESOLVED">{t('grievances.resolved')}</option>
          <option value="CLOSED">{t('grievances.closed')}</option>
        </select>
      </div>

      <div className="space-y-3">
        {(data?.grievances ?? []).map((g) => (
          <div key={g.id} className="glass-card p-5">
            <div className="flex items-start justify-between mb-3 gap-3">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1 flex-wrap">
                  <span className="text-xs text-slate-500 font-mono">{g.ticketNo}</span>
                  <span className={`px-2 py-0.5 text-xs rounded border ${PRIORITY_COLORS[g.priority]}`}>
                    {t(`grievances.${g.priority.toLowerCase()}`)}
                  </span>
                  <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_COLORS[g.status]}`}>
                    {t(`grievances.${g.status.toLowerCase().replace('_', '')}`, g.status)}
                  </span>
                </div>
                <h3 className="font-semibold text-white">{isMr && g.titleMr ? g.titleMr : g.title}</h3>
                <p className="text-sm text-slate-400 mt-1">{isMr && g.descriptionMr ? g.descriptionMr : g.description}</p>
                <div className="flex items-center gap-3 mt-3 text-xs text-slate-500">
                  <span>{g.raisedBy?.name}</span>
                  <span>•</span>
                  <span>{new Date(g.createdAt).toLocaleDateString()}</span>
                </div>
              </div>
              {isAdmin && g.status !== 'RESOLVED' && g.status !== 'CLOSED' && (
                <div className="flex flex-col gap-2">
                  <button
                    onClick={() => updateStatus(g, 'IN_PROGRESS')}
                    className="px-3 py-1.5 text-xs rounded-lg bg-cyan-500/10 text-cyan-400 hover:bg-cyan-500/20 border border-cyan-500/30"
                  >
                    {t('grievances.inProgress')}
                  </button>
                  <button
                    onClick={() => updateStatus(g, 'RESOLVED')}
                    className="px-3 py-1.5 text-xs rounded-lg bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 border border-emerald-500/30"
                  >
                    {t('grievances.markResolved')}
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('grievances.newGrievance')}>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('grievances.subject')}</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('grievances.description')}</label>
            <textarea rows={4} className="input-cyber" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('grievances.category')}</label>
              <select className="input-cyber" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>{t(`grievances.${c.toLowerCase()}`, c)}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('grievances.priority')}</label>
              <select className="input-cyber" value={form.priority} onChange={(e) => setForm({ ...form, priority: e.target.value })}>
                {PRIORITIES.map((p) => (
                  <option key={p} value={p}>{t(`grievances.${p.toLowerCase()}`)}</option>
                ))}
              </select>
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
