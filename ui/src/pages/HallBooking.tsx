import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CalendarDays, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { hallBookingsApi, HallBooking as HallBookingType } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const STATUS_COLORS: Record<string, string> = {
  PENDING: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/30',
  APPROVED: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
  REJECTED: 'bg-red-500/10 text-red-400 border-red-500/30',
  CANCELLED: 'bg-slate-500/10 text-slate-400 border-slate-500/30',
  COMPLETED: 'bg-purple-500/10 text-purple-400 border-purple-500/30',
}

export default function HallBooking() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    purpose: '', purposeMr: '', eventType: '',
    expectedGuests: 50,
    startTime: new Date(Date.now() + 864e5).toISOString().slice(0, 16),
    endTime: new Date(Date.now() + 864e5 + 4 * 3600e3).toISOString().slice(0, 16),
    bookingCharge: 2000,
    deposit: 5000,
  })

  const { data, loading, error, reload } = useApi(() => hallBookingsApi.list(), [])

  const create = async () => {
    try {
      await hallBookingsApi.create({
        ...form,
        startTime: new Date(form.startTime).toISOString(),
        endTime: new Date(form.endTime).toISOString(),
      })
      setModalOpen(false)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const decide = async (b: HallBookingType, approve: boolean) => {
    try {
      await hallBookingsApi.decide(b.id, approve)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('hallBooking.title')}
      icon={CalendarDays}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('hallBooking.bookHall')}
        </button>
      }
    >
      <div className="space-y-3">
        {(data?.bookings ?? []).map((b) => (
          <div key={b.id} className="glass-card p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-2">
                  <h3 className="font-semibold text-white">{b.purpose}</h3>
                  <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_COLORS[b.status]}`}>
                    {t(`hallBooking.${b.status.toLowerCase()}`, b.status)}
                  </span>
                </div>
                <p className="text-xs text-slate-400">
                  {new Date(b.startTime).toLocaleString()} — {new Date(b.endTime).toLocaleString()}
                </p>
                <div className="flex gap-4 mt-2 text-xs text-slate-500">
                  <span>{t('hallBooking.bookedBy')}: {b.bookedBy?.name ?? '—'}</span>
                  {!!b.expectedGuests && <span>{t('hallBooking.expectedGuests')}: {b.expectedGuests}</span>}
                  {b.bookingCharge > 0 && <span>{t('hallBooking.charge')}: ₹{b.bookingCharge}</span>}
                </div>
              </div>
              {isAdmin && b.status === 'PENDING' && (
                <div className="flex flex-col gap-2">
                  <button onClick={() => decide(b, true)} className="px-3 py-1.5 text-xs rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/20">
                    {t('hallBooking.approve')}
                  </button>
                  <button onClick={() => decide(b, false)} className="px-3 py-1.5 text-xs rounded-lg bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20">
                    {t('hallBooking.reject')}
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('hallBooking.bookHall')} size="lg">
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.purpose')} (EN)</label>
            <input className="input-cyber" value={form.purpose} onChange={(e) => setForm({ ...form, purpose: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.purpose')} (मराठी)</label>
            <input className="input-cyber" value={form.purposeMr} onChange={(e) => setForm({ ...form, purposeMr: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.startTime')}</label>
              <input type="datetime-local" className="input-cyber" value={form.startTime} onChange={(e) => setForm({ ...form, startTime: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.endTime')}</label>
              <input type="datetime-local" className="input-cyber" value={form.endTime} onChange={(e) => setForm({ ...form, endTime: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.expectedGuests')}</label>
              <input type="number" className="input-cyber" value={form.expectedGuests} onChange={(e) => setForm({ ...form, expectedGuests: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.charge')}</label>
              <input type="number" className="input-cyber" value={form.bookingCharge} onChange={(e) => setForm({ ...form, bookingCharge: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('hallBooking.deposit')}</label>
              <input type="number" className="input-cyber" value={form.deposit} onChange={(e) => setForm({ ...form, deposit: +e.target.value })} />
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
