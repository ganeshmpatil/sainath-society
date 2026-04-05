import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ArrowLeftRight, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { tenantsApi, Tenant } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function MoveInOut() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    name: '', mobile: '', email: '',
    agreementStart: '', agreementEnd: '',
    monthlyRent: 0, deposit: 0, familyCount: 1,
  })

  const { data, loading, error, reload } = useApi(() => tenantsApi.list(), [])

  const create = async () => {
    try {
      await tenantsApi.create({
        ...form,
        agreementStart: form.agreementStart ? new Date(form.agreementStart).toISOString() : undefined,
        agreementEnd: form.agreementEnd ? new Date(form.agreementEnd).toISOString() : undefined,
      } as Partial<Tenant>)
      setModalOpen(false)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const approve = async (id: string) => {
    try {
      await tenantsApi.approve(id)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('moveInOut.title')}
      icon={ArrowLeftRight}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('moveInOut.newRequest')}
        </button>
      }
    >
      <div className="space-y-3">
        {(data?.tenants ?? []).map((tn) => (
          <div key={tn.id} className="glass-card p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-semibold text-white">{tn.name}</h3>
                  <span className="px-2 py-0.5 text-xs rounded border bg-cyan-500/10 text-cyan-400 border-cyan-500/30">
                    {t(`moveInOut.${tn.status.toLowerCase()}`, tn.status)}
                  </span>
                </div>
                <div className="flex gap-4 mt-2 text-xs text-slate-500 flex-wrap">
                  <span>{t('moveInOut.mobile')}: {tn.mobile}</span>
                  <span>{t('moveInOut.flat')}: {tn.flat?.flatNumber ?? '—'}</span>
                  <span>{t('moveInOut.familyCount')}: {tn.familyCount}</span>
                  {!!tn.monthlyRent && <span>{t('moveInOut.monthlyRent')}: ₹{tn.monthlyRent}</span>}
                </div>
              </div>
              {isAdmin && tn.status === 'PENDING' && (
                <button onClick={() => approve(tn.id)} className="px-3 py-1.5 text-xs rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/20">
                  {t('moveInOut.approve')}
                </button>
              )}
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('moveInOut.newRequest')} size="lg">
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.name')}</label>
              <input className="input-cyber" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.mobile')}</label>
              <input className="input-cyber" value={form.mobile} onChange={(e) => setForm({ ...form, mobile: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.agreementStart')}</label>
              <input type="date" className="input-cyber" value={form.agreementStart} onChange={(e) => setForm({ ...form, agreementStart: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.agreementEnd')}</label>
              <input type="date" className="input-cyber" value={form.agreementEnd} onChange={(e) => setForm({ ...form, agreementEnd: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.monthlyRent')}</label>
              <input type="number" className="input-cyber" value={form.monthlyRent} onChange={(e) => setForm({ ...form, monthlyRent: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.deposit')}</label>
              <input type="number" className="input-cyber" value={form.deposit} onChange={(e) => setForm({ ...form, deposit: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('moveInOut.familyCount')}</label>
              <input type="number" className="input-cyber" value={form.familyCount} onChange={(e) => setForm({ ...form, familyCount: +e.target.value })} />
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
