import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Calendar, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { meetingsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const TYPES = ['AGM', 'SGM', 'COMMITTEE', 'EMERGENCY', 'REVIEW']

export default function Meetings() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    title: '', titleMr: '',
    meetingType: 'COMMITTEE',
    scheduledAt: new Date(Date.now() + 864e5).toISOString().slice(0, 16),
    location: '', agenda: '', agendaMr: '',
  })

  const { data, loading, error, reload } = useApi(() => meetingsApi.list(), [])

  const create = async () => {
    try {
      await meetingsApi.create({
        ...form,
        scheduledAt: new Date(form.scheduledAt).toISOString(),
      })
      setModalOpen(false)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('meetings.title')}
      icon={Calendar}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('meetings.newMeeting')}
          </button>
        )
      }
    >
      <div className="space-y-3">
        {(data?.meetings ?? []).map((m) => (
          <div key={m.id} className="glass-card p-5">
            <div className="flex items-start justify-between mb-3">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="px-2 py-0.5 text-xs rounded border bg-purple-500/10 text-purple-400 border-purple-500/30">
                    {t(`meetings.${m.meetingType.toLowerCase()}`, m.meetingType)}
                  </span>
                  <span className="px-2 py-0.5 text-xs rounded border bg-cyan-500/10 text-cyan-400 border-cyan-500/30">
                    {t(`meetings.status.${m.status.toLowerCase()}`, m.status)}
                  </span>
                </div>
                <h3 className="font-semibold text-white">{isMr && m.titleMr ? m.titleMr : m.title}</h3>
                <p className="text-xs text-slate-400 mt-1">
                  {new Date(m.scheduledAt).toLocaleString()} {m.location && `• ${m.location}`}
                </p>
              </div>
            </div>
            {m.agenda && (
              <div className="mt-3 p-3 rounded-lg bg-slate-800/50">
                <p className="text-xs font-semibold text-purple-400 mb-1">{t('meetings.agenda')}</p>
                <p className="text-sm text-slate-300 whitespace-pre-line">{isMr && m.agendaMr ? m.agendaMr : m.agenda}</p>
              </div>
            )}
            {m.minutesOfMeeting && (
              <div className="mt-3 p-3 rounded-lg bg-emerald-500/5 border border-emerald-500/20">
                <p className="text-xs font-semibold text-emerald-400 mb-1">{t('meetings.mom')}</p>
                <p className="text-sm text-slate-300 whitespace-pre-line">{isMr && m.minutesOfMeetingMr ? m.minutesOfMeetingMr : m.minutesOfMeeting}</p>
              </div>
            )}
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('meetings.newMeeting')} size="lg">
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('meetings.subject')} (EN)</label>
            <input className="input-cyber" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('meetings.subject')} (मराठी)</label>
            <input className="input-cyber" value={form.titleMr} onChange={(e) => setForm({ ...form, titleMr: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('meetings.scheduledAt')}</label>
              <input type="datetime-local" className="input-cyber" value={form.scheduledAt} onChange={(e) => setForm({ ...form, scheduledAt: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('common.category')}</label>
              <select className="input-cyber" value={form.meetingType} onChange={(e) => setForm({ ...form, meetingType: e.target.value })}>
                {TYPES.map((tp) => <option key={tp} value={tp}>{t(`meetings.${tp.toLowerCase()}`, tp)}</option>)}
              </select>
            </div>
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('meetings.location')}</label>
            <input className="input-cyber" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('meetings.agenda')}</label>
            <textarea rows={3} className="input-cyber" value={form.agenda} onChange={(e) => setForm({ ...form, agenda: e.target.value })} />
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
