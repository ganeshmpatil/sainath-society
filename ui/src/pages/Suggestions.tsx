import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Lightbulb, Plus, ThumbsUp } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { suggestionsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function Suggestions() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [sortBy, setSortBy] = useState<'recent' | 'upvotes'>('upvotes')
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ title: '', titleMr: '', description: '', descriptionMr: '', category: '' })

  const { data, loading, error, reload } = useApi(() => suggestionsApi.list({ sortBy }), [sortBy])

  const create = async () => {
    try {
      await suggestionsApi.create(form)
      setModalOpen(false)
      setForm({ title: '', titleMr: '', description: '', descriptionMr: '', category: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const upvote = async (id: string) => {
    try {
      await suggestionsApi.upvote(id)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('suggestions.title')}
      icon={Lightbulb}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('suggestions.newSuggestion')}
        </button>
      }
    >
      <div className="glass-card p-4 mb-4 flex gap-2">
        <button
          onClick={() => setSortBy('upvotes')}
          className={`px-3 py-1.5 text-sm rounded-lg ${sortBy === 'upvotes' ? 'bg-purple-500/20 text-purple-400 border border-purple-500/30' : 'text-slate-400'}`}
        >
          {t('suggestions.sortUpvotes')}
        </button>
        <button
          onClick={() => setSortBy('recent')}
          className={`px-3 py-1.5 text-sm rounded-lg ${sortBy === 'recent' ? 'bg-purple-500/20 text-purple-400 border border-purple-500/30' : 'text-slate-400'}`}
        >
          {t('suggestions.sortRecent')}
        </button>
      </div>

      <div className="space-y-3">
        {(data?.suggestions ?? []).map((s) => (
          <div key={s.id} className="glass-card p-5">
            <div className="flex items-start gap-4">
              <button
                onClick={() => upvote(s.id)}
                className="flex flex-col items-center gap-1 p-3 rounded-xl bg-slate-800/50 hover:bg-purple-500/10 border border-purple-500/20 hover:border-purple-500/40 transition-all"
              >
                <ThumbsUp size={16} className="text-purple-400" />
                <span className="text-sm font-bold text-white">{s.upvoteCount}</span>
              </button>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-semibold text-white">{isMr && s.titleMr ? s.titleMr : s.title}</h3>
                  <span className="px-2 py-0.5 text-xs rounded border bg-cyan-500/10 text-cyan-400 border-cyan-500/30">
                    {s.status}
                  </span>
                </div>
                <p className="text-sm text-slate-400 mt-1">{isMr && s.descriptionMr ? s.descriptionMr : s.description}</p>
                <div className="text-xs text-slate-500 mt-2">
                  {s.raisedBy?.name} • {new Date(s.createdAt).toLocaleDateString()}
                </div>
                {s.adminResponse && (
                  <div className="mt-3 p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/20">
                    <p className="text-xs font-semibold text-emerald-400 mb-1">{t('suggestions.adminResponse')}</p>
                    <p className="text-sm text-slate-300">{s.adminResponse}</p>
                  </div>
                )}
                {isAdmin && !s.adminResponse && (
                  <button
                    onClick={async () => {
                      const resp = prompt(t('suggestions.adminResponse') ?? 'Response')
                      if (resp) {
                        await suggestionsApi.respond(s.id, 'ACCEPTED', resp)
                        reload()
                      }
                    }}
                    className="mt-2 text-xs text-purple-400 hover:text-purple-300"
                  >
                    {t('suggestions.respond')}
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('suggestions.newSuggestion')} size="lg">
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('suggestions.subject')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('suggestions.subject')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('suggestions.description')}</label>
            <textarea rows={4} className="input-cyber" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
