import { useTranslation } from 'react-i18next'
import { FileText } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { meetingsApi } from '../api/resources'
import PageShell from '../components/PageShell'

/**
 * Decisions page = flattened view of MoM (minutes of meeting) from completed
 * meetings. Each meeting with saved minutes is one row in the decision log.
 */
export default function Decisions() {
  const { t, i18n } = useTranslation()
  const isMr = i18n.language === 'mr'
  const { data, loading, error, reload } = useApi(() => meetingsApi.list(), [])

  const decisions = (data?.meetings ?? []).filter((m) => m.minutesOfMeeting)

  return (
    <PageShell
      title={t('decisions.title')}
      subtitle={t('decisions.derivedNote')}
      icon={FileText}
      loading={loading}
      error={error}
      onRetry={reload}
    >
      <div className="space-y-3">
        {decisions.map((m) => (
          <div key={m.id} className="glass-card p-5">
            <div className="flex items-center gap-2 mb-2">
              <span className="px-2 py-0.5 text-xs rounded border bg-purple-500/10 text-purple-400 border-purple-500/30">
                {t(`meetings.${m.meetingType.toLowerCase()}`, m.meetingType)}
              </span>
              <span className="text-xs text-slate-500">
                {new Date(m.scheduledAt).toLocaleDateString()}
              </span>
            </div>
            <h3 className="font-semibold text-white mb-2">{isMr && m.titleMr ? m.titleMr : m.title}</h3>
            <p className="text-sm text-slate-300 whitespace-pre-line">
              {isMr && m.minutesOfMeetingMr ? m.minutesOfMeetingMr : m.minutesOfMeeting}
            </p>
            {m.actionItems && m.actionItems.length > 0 && (
              <div className="mt-3 p-3 rounded-lg bg-slate-800/50">
                <p className="text-xs font-semibold text-cyan-400 mb-2">{t('meetings.actionItems')}</p>
                <ul className="space-y-1 text-sm text-slate-300">
                  {m.actionItems.map((a) => (
                    <li key={a.id}>• {a.title} — {a.owner?.name ?? '—'}</li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        ))}
        {decisions.length === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>
    </PageShell>
  )
}
