import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bell, Plus, Pin } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { noticesApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const CATEGORIES = ['GENERAL', 'MAINTENANCE', 'AGM', 'EMERGENCY', 'FESTIVAL', 'RULE_CHANGE']

export default function Notices() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ title: '', titleMr: '', body: '', bodyMr: '', category: 'GENERAL', isPinned: false })

  const { data, loading, error, reload } = useApi(() => noticesApi.list(), [])

  const create = async () => {
    try {
      await noticesApi.create(form)
      setModalOpen(false)
      setForm({ title: '', titleMr: '', body: '', bodyMr: '', category: 'GENERAL', isPinned: false })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('notices.title')}
      icon={Bell}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('notices.newNotice')}
          </button>
        )
      }
    >
      <div className="space-y-3">
        {(data?.notices ?? []).map((n) => (
          <div key={n.id} className={`glass-card p-5 ${n.isPinned ? 'border-l-4 border-cyan-500' : ''}`}>
            <div className="flex items-start justify-between gap-3 mb-2">
              <h3 className="font-semibold text-white flex-1 flex items-center gap-2">
                {n.isPinned && <Pin size={14} className="text-cyan-400" />}
                {isMr && n.titleMr ? n.titleMr : n.title}
              </h3>
              <span className="px-2 py-0.5 text-xs rounded border bg-purple-500/10 text-purple-400 border-purple-500/30">
                {t(`notices.${n.category.toLowerCase().replace('_', '')}`, n.category)}
              </span>
            </div>
            <p className="text-sm text-slate-400 mb-3 whitespace-pre-line">{isMr && n.bodyMr ? n.bodyMr : n.body}</p>
            <div className="text-xs text-slate-500">
              {n.createdBy?.name} • {new Date(n.createdAt).toLocaleDateString()}
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('notices.newNotice')} size="lg">
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('notices.title2')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('notices.title2')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('notices.body')} (EN)</label>
            <textarea rows={3} className="input-cyber" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('notices.body')} (मराठी)</label>
            <textarea rows={3} className="input-cyber" value={form.bodyMr} onChange={(e) => setForm({ ...form, bodyMr: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3 items-end">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('common.category')}</label>
              <select className="input-cyber" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>{t(`notices.${c.toLowerCase().replace('_', '')}`, c)}</option>
                ))}
              </select>
            </div>
            <label className="flex items-center gap-2 text-sm text-slate-300">
              <input type="checkbox" checked={form.isPinned} onChange={(e) => setForm({ ...form, isPinned: e.target.checked })} />
              {t('notices.pin')}
            </label>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
