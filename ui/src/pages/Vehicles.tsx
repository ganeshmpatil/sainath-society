import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Car, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { vehiclesApi } from '../api/resources'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const TYPES = ['CAR', 'BIKE', 'BICYCLE', 'COMMERCIAL', 'EV', 'OTHER']

export default function Vehicles() {
  const { t } = useTranslation()
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ registrationNo: '', vehicleType: 'CAR', make: '', model: '', color: '', parkingSlot: '' })

  const { data, loading, error, reload } = useApi(() => vehiclesApi.list(), [])

  const create = async () => {
    try {
      await vehiclesApi.create(form)
      setModalOpen(false)
      setForm({ registrationNo: '', vehicleType: 'CAR', make: '', model: '', color: '', parkingSlot: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('vehicles.title')}
      icon={Car}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
          <Plus size={16} /> {t('vehicles.registerVehicle')}
        </button>
      }
    >
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {(data?.vehicles ?? []).map((v) => (
          <div key={v.id} className="glass-card p-5">
            <div className="flex items-start justify-between mb-3">
              <div>
                <p className="text-lg font-bold text-white font-mono">{v.registrationNo}</p>
                <p className="text-xs text-slate-400 mt-1">
                  {v.make} {v.model} {v.color && `• ${v.color}`}
                </p>
              </div>
              <span className="px-2 py-0.5 text-xs rounded border bg-purple-500/10 text-purple-400 border-purple-500/30">
                {t(`vehicles.${v.vehicleType.toLowerCase()}`, v.vehicleType)}
              </span>
            </div>
            <div className="text-xs text-slate-500 space-y-1">
              <p>{t('vehicles.owner')}: {v.owner?.name ?? '—'}</p>
              <p>{t('vehicles.flat')}: {v.flat?.flatNumber ?? '—'}</p>
              {v.parkingSlot && <p>{t('vehicles.parkingSlot')}: {v.parkingSlot}</p>}
            </div>
          </div>
        ))}
        {data?.count === 0 && <p className="col-span-full text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('vehicles.registerVehicle')}>
        <div className="space-y-3">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('vehicles.registrationNo')}</label>
            <input className="input-cyber" value={form.registrationNo} onChange={(e) => setForm({ ...form, registrationNo: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('vehicles.type')}</label>
            <select className="input-cyber" value={form.vehicleType} onChange={(e) => setForm({ ...form, vehicleType: e.target.value })}>
              {TYPES.map((tp) => <option key={tp} value={tp}>{t(`vehicles.${tp.toLowerCase()}`, tp)}</option>)}
            </select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('vehicles.make')}</label>
              <input className="input-cyber" value={form.make} onChange={(e) => setForm({ ...form, make: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('vehicles.model')}</label>
              <input className="input-cyber" value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('vehicles.color')}</label>
              <input className="input-cyber" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('vehicles.parkingSlot')}</label>
              <input className="input-cyber" value={form.parkingSlot} onChange={(e) => setForm({ ...form, parkingSlot: e.target.value })} />
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
