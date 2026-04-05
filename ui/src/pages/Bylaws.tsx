import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { BookOpen, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { bylawsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function Bylaws() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ section: '', title: '', titleMr: '', content: '', contentMr: '', category: '' })

  const { data, loading, error, reload } = useApi(() => bylawsApi.list(), [])

  const create = async () => {
    try {
      await bylawsApi.create(form)
      setModalOpen(false)
      setForm({ section: '', title: '', titleMr: '', content: '', contentMr: '', category: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('bylaws.title')}
      icon={BookOpen}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('bylaws.addBylaw')}
          </button>
        )
      }
    >
      <div className="space-y-3">
        {(data?.bylaws ?? []).map((b) => (
          <div key={b.id} className="glass-card p-5">
            <div className="flex items-start justify-between mb-2">
              <div>
                <span className="text-xs font-mono text-cyan-400 bg-cyan-500/10 px-2 py-0.5 rounded border border-cyan-500/30">
                  §{b.section}
                </span>
                <h3 className="font-semibold text-white mt-2">{isMr && b.titleMr ? b.titleMr : b.title}</h3>
              </div>
              <span className="text-xs text-slate-500">
                {t('bylaws.version')} {b.version}
              </span>
            </div>
            <p className="text-sm text-slate-400 mt-3 whitespace-pre-line">{isMr && b.contentMr ? b.contentMr : b.content}</p>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('bylaws.addBylaw')} size="lg">
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('bylaws.section')}</label>
            <input className="input-cyber" value={form.section} onChange={(e) => setForm({ ...form, section: e.target.value })} placeholder="3.2.1" />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('common.title')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('common.title')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('bylaws.content')} (EN)</label>
            <textarea rows={3} className="input-cyber" value={form.content} onChange={(e) => setForm({ ...form, content: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('bylaws.content')} (मराठी)</label>
            <textarea rows={3} className="input-cyber" value={form.contentMr} onChange={(e) => setForm({ ...form, contentMr: e.target.value })} />
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
