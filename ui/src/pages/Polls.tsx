import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Vote, Plus, Trash2 } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { pollsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function Polls() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    title: '', titleMr: '', description: '',
    startsAt: new Date().toISOString().slice(0, 16),
    endsAt: new Date(Date.now() + 7 * 864e5).toISOString().slice(0, 16),
    options: [{ optionText: '', optionTextMr: '' }, { optionText: '', optionTextMr: '' }],
  })

  const { data, loading, error, reload } = useApi(() => pollsApi.list(), [])

  const create = async () => {
    try {
      await pollsApi.create({
        title: form.title,
        titleMr: form.titleMr,
        description: form.description,
        startsAt: new Date(form.startsAt).toISOString(),
        endsAt: new Date(form.endsAt).toISOString(),
        options: form.options.filter((o) => o.optionText),
      })
      setModalOpen(false)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const vote = async (pollId: string, optionId: string) => {
    try {
      await pollsApi.vote(pollId, optionId)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const publish = async (id: string) => {
    await pollsApi.publish(id)
    reload()
  }

  const closePoll = async (id: string) => {
    await pollsApi.close(id)
    reload()
  }

  return (
    <PageShell
      title={t('polls.title')}
      icon={Vote}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('polls.newPoll')}
          </button>
        )
      }
    >
      <div className="space-y-4">
        {(data?.polls ?? []).map((p) => {
          const totalVotes = p.options.reduce((a, o) => a + o.voteCount, 0)
          return (
            <div key={p.id} className="glass-card p-5">
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`px-2 py-0.5 text-xs rounded border ${
                      p.status === 'ACTIVE' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30' :
                      p.status === 'CLOSED' ? 'bg-slate-500/10 text-slate-400 border-slate-500/30' :
                      'bg-cyan-500/10 text-cyan-400 border-cyan-500/30'
                    }`}>
                      {t(`polls.${p.status.toLowerCase()}`)}
                    </span>
                  </div>
                  <h3 className="font-semibold text-white">{isMr && p.titleMr ? p.titleMr : p.title}</h3>
                  <p className="text-xs text-slate-500 mt-1">
                    {new Date(p.startsAt).toLocaleDateString()} — {new Date(p.endsAt).toLocaleDateString()} • {totalVotes} {t('polls.totalVotes')}
                  </p>
                </div>
                {isAdmin && (
                  <div className="flex gap-2">
                    {p.status === 'DRAFT' && (
                      <button onClick={() => publish(p.id)} className="text-xs text-emerald-400 hover:text-emerald-300">
                        {t('polls.publish')}
                      </button>
                    )}
                    {p.status === 'ACTIVE' && (
                      <button onClick={() => closePoll(p.id)} className="text-xs text-red-400 hover:text-red-300">
                        {t('polls.closePoll')}
                      </button>
                    )}
                  </div>
                )}
              </div>
              <div className="space-y-2">
                {p.options.map((o) => {
                  const pct = totalVotes > 0 ? (o.voteCount / totalVotes) * 100 : 0
                  return (
                    <button
                      key={o.id}
                      onClick={() => p.status === 'ACTIVE' && vote(p.id, o.id)}
                      disabled={p.status !== 'ACTIVE'}
                      className="w-full text-left relative overflow-hidden p-3 rounded-lg bg-slate-800/50 hover:bg-slate-800 border border-purple-500/10 hover:border-purple-500/30 transition-all disabled:cursor-not-allowed"
                    >
                      <div
                        className="absolute inset-0 bg-gradient-to-r from-purple-500/10 to-cyan-500/10"
                        style={{ width: `${pct}%` }}
                      />
                      <div className="relative flex items-center justify-between">
                        <span className="text-white text-sm">{isMr && o.optionTextMr ? o.optionTextMr : o.optionText}</span>
                        <span className="text-xs text-slate-400">{o.voteCount} ({pct.toFixed(0)}%)</span>
                      </div>
                    </button>
                  )
                })}
              </div>
            </div>
          )
        })}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('polls.newPoll')} size="lg">
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('polls.question')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('polls.question')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('polls.startDate')}</label>
              <input type="datetime-local" className="input-cyber" value={form.startsAt} onChange={(e) => setForm({ ...form, startsAt: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('polls.endDate')}</label>
              <input type="datetime-local" className="input-cyber" value={form.endsAt} onChange={(e) => setForm({ ...form, endsAt: e.target.value })} />
            </div>
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-2">{t('polls.options')}</label>
            {form.options.map((o, i) => (
              <div key={i} className="flex gap-2 mb-2">
                <input
                  className="input-cyber flex-1"
                  placeholder={`${i + 1}. EN`}
                  value={o.optionText}
                  onChange={(e) => {
                    const next = [...form.options]
                    next[i] = { ...next[i], optionText: e.target.value }
                    setForm({ ...form, options: next })
                  }}
                />
                <input
                  className="input-cyber flex-1"
                  placeholder="मराठी"
                  value={o.optionTextMr}
                  onChange={(e) => {
                    const next = [...form.options]
                    next[i] = { ...next[i], optionTextMr: e.target.value }
                    setForm({ ...form, options: next })
                  }}
                />
                {form.options.length > 2 && (
                  <button
                    onClick={() => setForm({ ...form, options: form.options.filter((_, idx) => idx !== i) })}
                    className="px-2 text-red-400 hover:text-red-300"
                  >
                    <Trash2 size={16} />
                  </button>
                )}
              </div>
            ))}
            <button
              onClick={() => setForm({ ...form, options: [...form.options, { optionText: '', optionTextMr: '' }] })}
              className="text-xs text-purple-400 hover:text-purple-300"
            >
              + {t('polls.addOption')}
            </button>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
