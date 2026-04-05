import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CheckSquare, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { tasksApi, Task } from '../api/resources'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const PRIORITY_COLORS: Record<string, string> = {
  URGENT: 'bg-red-500/10 text-red-400 border-red-500/30',
  HIGH: 'bg-orange-500/10 text-orange-400 border-orange-500/30',
  MEDIUM: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
  LOW: 'bg-green-500/10 text-green-400 border-green-500/30',
}

const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT']

export default function PendingTasks() {
  const { t, i18n } = useTranslation()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ title: '', titleMr: '', description: '', priority: 'MEDIUM', dueDate: '' })

  const { data, loading, error, reload } = useApi(() => tasksApi.list(), [])

  const create = async () => {
    try {
      await tasksApi.create({
        ...form,
        dueDate: form.dueDate ? new Date(form.dueDate).toISOString() : undefined,
      } as Partial<Task>)
      setModalOpen(false)
      setForm({ title: '', titleMr: '', description: '', priority: 'MEDIUM', dueDate: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const updateStatus = async (id: string, status: string) => {
    try {
      await tasksApi.updateStatus(id, status)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('tasks.title')}
      icon={CheckSquare}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('tasks.newTask')}
        </button>
      }
    >
      <div className="space-y-3">
        {(data?.tasks ?? []).map((task) => (
          <div key={task.id} className="glass-card p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <span className={`px-2 py-0.5 text-xs rounded border ${PRIORITY_COLORS[task.priority]}`}>
                    {task.priority}
                  </span>
                  <span className="px-2 py-0.5 text-xs rounded border bg-cyan-500/10 text-cyan-400 border-cyan-500/30">
                    {t(`tasks.${task.status.toLowerCase().replace('_', '')}`, task.status)}
                  </span>
                </div>
                <h3 className="font-semibold text-white">{isMr && task.titleMr ? task.titleMr : task.title}</h3>
                {task.description && <p className="text-sm text-slate-400 mt-1">{task.description}</p>}
                <div className="flex gap-4 mt-2 text-xs text-slate-500">
                  <span>{t('tasks.assignedTo')}: {task.owner?.name ?? '—'}</span>
                  {task.dueDate && <span>{t('tasks.dueDate')}: {new Date(task.dueDate).toLocaleDateString()}</span>}
                </div>
              </div>
              <div className="flex flex-col gap-2">
                {task.status === 'PENDING' && (
                  <button onClick={() => updateStatus(task.id, 'IN_PROGRESS')} className="px-3 py-1.5 text-xs rounded-lg bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 hover:bg-cyan-500/20">
                    {t('tasks.markInProgress')}
                  </button>
                )}
                {task.status !== 'COMPLETED' && (
                  <button onClick={() => updateStatus(task.id, 'COMPLETED')} className="px-3 py-1.5 text-xs rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/20">
                    {t('tasks.markCompleted')}
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('tasks.newTask')}>
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('tasks.taskName')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('tasks.taskName')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('common.description')}</label>
            <textarea rows={3} className="input-cyber" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('tasks.priority')}</label>
              <select className="input-cyber" value={form.priority} onChange={(e) => setForm({ ...form, priority: e.target.value })}>
                {PRIORITIES.map((p) => <option key={p} value={p}>{p}</option>)}
              </select>
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('tasks.dueDate')}</label>
              <input type="date" className="input-cyber" value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: e.target.value })} />
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
