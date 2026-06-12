import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Mail, Send, Users, CheckCircle, AlertCircle, Clock } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { notificationsApi, residentsApi, type Resident } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

type Tab = 'compose' | 'inbox'

export default function EmailNotifications() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [tab, setTab] = useState<Tab>(isAdmin ? 'compose' : 'inbox')
  const [modalOpen, setModalOpen] = useState(false)
  const [sendMode, setSendMode] = useState<'selected' | 'all'>('all')
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [form, setForm] = useState({ subject: '', body: '', bodyMr: '' })
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState<{ queued: number; skipped?: number } | null>(null)

  const { data: inboxData, loading: inboxLoading, error: inboxError, reload: reloadInbox } = useApi(
    () => notificationsApi.inbox(), []
  )
  const { data: residentsData } = useApi(
    () => residentsApi.list({ activeOnly: true }), []
  )

  const residents = residentsData?.residents ?? []

  const toggleRecipient = (id: string) => {
    setSelectedIds(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id])
  }

  const handleSend = async () => {
    if (!form.subject.trim() || !form.body.trim()) return
    setSending(true)
    setResult(null)
    try {
      if (sendMode === 'all') {
        const res = await notificationsApi.sendEmailToAll({
          subject: form.subject,
          body: form.body,
          bodyMr: form.bodyMr || undefined,
        })
        setResult({ queued: res.queued })
      } else {
        if (selectedIds.length === 0) return
        const res = await notificationsApi.sendEmail({
          recipientIds: selectedIds,
          subject: form.subject,
          body: form.body,
          bodyMr: form.bodyMr || undefined,
        })
        setResult({ queued: res.queued, skipped: res.skipped })
      }
      setForm({ subject: '', body: '', bodyMr: '' })
      setSelectedIds([])
      setModalOpen(false)
      reloadInbox()
    } catch (e) {
      alert((e as Error).message)
    } finally {
      setSending(false)
    }
  }

  const statusIcon = (status: string) => {
    switch (status) {
      case 'SENT': case 'DELIVERED': return <CheckCircle size={14} className="text-green-400" />
      case 'FAILED': return <AlertCircle size={14} className="text-red-400" />
      default: return <Clock size={14} className="text-yellow-400" />
    }
  }

  const statusColor = (status: string) => {
    switch (status) {
      case 'SENT': case 'DELIVERED': return 'text-green-400 bg-green-500/10 border-green-500/30'
      case 'FAILED': return 'text-red-400 bg-red-500/10 border-red-500/30'
      default: return 'text-yellow-400 bg-yellow-500/10 border-yellow-500/30'
    }
  }

  return (
    <PageShell
      title={t('emailNotifications.title')}
      icon={Mail}
      loading={inboxLoading}
      error={inboxError}
      onRetry={reloadInbox}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Send size={16} /> {t('emailNotifications.sendEmail')}
          </button>
        )
      }
    >
      {/* Tab switcher */}
      {isAdmin && (
        <div className="flex gap-2 mb-6">
          {(['compose', 'inbox'] as Tab[]).map(t2 => (
            <button
              key={t2}
              onClick={() => setTab(t2)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
                tab === t2
                  ? 'bg-purple-500/20 text-purple-400 border border-purple-500/30'
                  : 'text-slate-400 hover:text-white hover:bg-white/5'
              }`}
            >
              {t2 === 'compose' ? t('emailNotifications.sendEmail') : t('emailNotifications.inbox')}
            </button>
          ))}
        </div>
      )}

      {/* Success result banner */}
      {result && (
        <div className="mb-4 p-4 rounded-xl bg-green-500/10 border border-green-500/30 flex items-center gap-3">
          <CheckCircle size={20} className="text-green-400" />
          <div>
            <p className="text-green-400 font-medium">{t('emailNotifications.sentSuccess')}</p>
            <p className="text-sm text-green-400/70">
              {result.queued} {t('emailNotifications.queued')}
              {result.skipped ? ` • ${result.skipped} ${t('emailNotifications.skipped')}` : ''}
            </p>
          </div>
        </div>
      )}

      {/* Compose tab (inline quick send) */}
      {tab === 'compose' && isAdmin && (
        <div className="glass-card p-6 space-y-4">
          <div className="flex gap-3 mb-4">
            <button
              onClick={() => setSendMode('all')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm transition-all ${
                sendMode === 'all'
                  ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                  : 'text-slate-400 hover:text-white bg-white/5'
              }`}
            >
              <Users size={16} /> {t('emailNotifications.sendToAll')}
            </button>
            <button
              onClick={() => setSendMode('selected')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm transition-all ${
                sendMode === 'selected'
                  ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                  : 'text-slate-400 hover:text-white bg-white/5'
              }`}
            >
              <Mail size={16} /> {t('emailNotifications.sendToSelected')}
            </button>
          </div>

          {sendMode === 'selected' && (
            <div>
              <label className="block text-sm text-slate-300 mb-2">{t('emailNotifications.selectRecipients')}</label>
              <div className="max-h-48 overflow-y-auto rounded-lg border border-purple-500/20 bg-slate-800/50 p-2 space-y-1">
                {residents.map((r: Resident) => (
                  <label
                    key={r.id}
                    className={`flex items-center gap-3 p-2 rounded-lg cursor-pointer transition-all ${
                      selectedIds.includes(r.id) ? 'bg-purple-500/10' : 'hover:bg-white/5'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={selectedIds.includes(r.id)}
                      onChange={() => toggleRecipient(r.id)}
                      className="accent-purple-500"
                    />
                    <span className="text-sm text-white">{r.name}</span>
                    <span className="text-xs text-slate-500">{r.flat?.flatNumber}</span>
                    {r.email
                      ? <span className="text-xs text-cyan-400 ml-auto">{r.email}</span>
                      : <span className="text-xs text-red-400/50 ml-auto">{t('emailNotifications.noEmail')}</span>
                    }
                  </label>
                ))}
              </div>
              {selectedIds.length > 0 && (
                <p className="text-xs text-cyan-400 mt-1">{selectedIds.length} {t('emailNotifications.recipientsSelected')}</p>
              )}
            </div>
          )}

          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.subject')}</label>
            <input
              className="input-cyber"
              placeholder={t('emailNotifications.subjectPlaceholder')}
              value={form.subject}
              onChange={e => setForm({ ...form, subject: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.body')}</label>
            <textarea
              rows={4}
              className="input-cyber"
              placeholder={t('emailNotifications.bodyPlaceholder')}
              value={form.body}
              onChange={e => setForm({ ...form, body: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.bodyMr')}</label>
            <textarea
              rows={3}
              className="input-cyber"
              placeholder={t('emailNotifications.bodyPlaceholder')}
              value={form.bodyMr}
              onChange={e => setForm({ ...form, bodyMr: e.target.value })}
            />
          </div>
          <button
            onClick={handleSend}
            disabled={sending || !form.subject.trim() || !form.body.trim() || (sendMode === 'selected' && selectedIds.length === 0)}
            className="cyber-button w-full flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Send size={16} /> {sending ? t('common.loading') : t('emailNotifications.sendEmail')}
          </button>
        </div>
      )}

      {/* Inbox tab */}
      {(tab === 'inbox' || !isAdmin) && (
        <div className="space-y-3">
          {(inboxData ?? []).map(n => (
            <div key={n.id} className="glass-card p-5">
              <div className="flex items-start justify-between gap-3 mb-2">
                <h3 className="font-semibold text-white flex-1 flex items-center gap-2">
                  {statusIcon(n.status)}
                  {n.subject || 'Notification'}
                </h3>
                <span className={`px-2 py-0.5 text-xs rounded border ${statusColor(n.status)}`}>
                  {n.status}
                </span>
              </div>
              <p className="text-sm text-slate-400 mb-2 whitespace-pre-line">{n.body}</p>
              <div className="flex items-center gap-3 text-xs text-slate-500">
                <span className="px-2 py-0.5 rounded bg-purple-500/10 text-purple-400 border border-purple-500/30">
                  {n.channel}
                </span>
                <span>{new Date(n.createdAt).toLocaleString()}</span>
                {n.failureReason && <span className="text-red-400">{n.failureReason}</span>}
              </div>
            </div>
          ))}
          {(inboxData ?? []).length === 0 && (
            <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>
          )}
        </div>
      )}

      {/* Send modal (quick access from button) */}
      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('emailNotifications.sendEmail')} size="lg">
        <div className="space-y-4">
          <div className="flex gap-3">
            <button
              onClick={() => setSendMode('all')}
              className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg text-sm transition-all ${
                sendMode === 'all'
                  ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                  : 'text-slate-400 bg-white/5 border border-transparent'
              }`}
            >
              <Users size={16} /> {t('emailNotifications.sendToAll')}
            </button>
            <button
              onClick={() => setSendMode('selected')}
              className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg text-sm transition-all ${
                sendMode === 'selected'
                  ? 'bg-cyan-500/20 text-cyan-400 border border-cyan-500/30'
                  : 'text-slate-400 bg-white/5 border border-transparent'
              }`}
            >
              <Mail size={16} /> {t('emailNotifications.sendToSelected')}
            </button>
          </div>

          {sendMode === 'selected' && (
            <div className="max-h-40 overflow-y-auto rounded-lg border border-purple-500/20 bg-slate-800/50 p-2 space-y-1">
              {residents.map((r: Resident) => (
                <label key={r.id} className="flex items-center gap-3 p-2 rounded-lg cursor-pointer hover:bg-white/5">
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(r.id)}
                    onChange={() => toggleRecipient(r.id)}
                    className="accent-purple-500"
                  />
                  <span className="text-sm text-white">{r.name}</span>
                  <span className="text-xs text-slate-500 ml-auto">{r.email || t('emailNotifications.noEmail')}</span>
                </label>
              ))}
            </div>
          )}

          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.subject')}</label>
            <input className="input-cyber" value={form.subject} onChange={e => setForm({ ...form, subject: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.body')}</label>
            <textarea rows={3} className="input-cyber" value={form.body} onChange={e => setForm({ ...form, body: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emailNotifications.bodyMr')}</label>
            <textarea rows={2} className="input-cyber" value={form.bodyMr} onChange={e => setForm({ ...form, bodyMr: e.target.value })} />
          </div>
          <button
            onClick={handleSend}
            disabled={sending || !form.subject || !form.body || (sendMode === 'selected' && selectedIds.length === 0)}
            className="cyber-button w-full disabled:opacity-50"
          >
            {sending ? t('common.loading') : t('emailNotifications.sendEmail')}
          </button>
        </div>
      </Modal>
    </PageShell>
  )
}
