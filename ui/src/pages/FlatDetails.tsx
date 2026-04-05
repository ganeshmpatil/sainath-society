import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Building2, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { flatsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function FlatDetails() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ flatNumber: '', floor: 1, areaSqft: 0, ownerName: '' })

  const flats = useApi(() => flatsApi.list(), [])
  const wings = useApi(() => flatsApi.listWings(), [])

  const create = async () => {
    try {
      await flatsApi.create(form)
      setModalOpen(false)
      setForm({ flatNumber: '', floor: 1, areaSqft: 0, ownerName: '' })
      flats.reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('flats.title')}
      icon={Building2}
      loading={flats.loading}
      error={flats.error}
      onRetry={flats.reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('flats.addFlat')}
          </button>
        )
      }
    >
      <div className="mb-4 text-sm text-slate-400">
        {t('common.total')}: {flats.data?.count ?? 0} • {wings.data?.count ?? 0} {t('flats.wing')}
      </div>
      <div className="glass-card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-800/50 text-slate-400 uppercase text-xs">
            <tr>
              <th className="text-left px-4 py-3">{t('flats.flatNumber')}</th>
              <th className="text-left px-4 py-3">{t('flats.wing')}</th>
              <th className="text-left px-4 py-3">{t('flats.floor')}</th>
              <th className="text-left px-4 py-3">{t('flats.area')}</th>
              <th className="text-left px-4 py-3">{t('flats.owner')}</th>
            </tr>
          </thead>
          <tbody>
            {(flats.data?.flats ?? []).map((f) => (
              <tr key={f.id} className="border-t border-purple-500/10 hover:bg-slate-800/30">
                <td className="px-4 py-3 font-medium text-white">{f.flatNumber}</td>
                <td className="px-4 py-3 text-slate-300">{f.wing?.name ?? '—'}</td>
                <td className="px-4 py-3 text-slate-300">{f.floor}</td>
                <td className="px-4 py-3 text-slate-300">{f.areaSqft}</td>
                <td className="px-4 py-3 text-slate-300">{f.ownerName || '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('flats.addFlat')}>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('flats.flatNumber')}</label>
            <input className="input-cyber" value={form.flatNumber} onChange={(e) => setForm({ ...form, flatNumber: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('flats.floor')}</label>
              <input type="number" className="input-cyber" value={form.floor} onChange={(e) => setForm({ ...form, floor: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('flats.area')}</label>
              <input type="number" className="input-cyber" value={form.areaSqft} onChange={(e) => setForm({ ...form, areaSqft: +e.target.value })} />
            </div>
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('flats.owner')}</label>
            <input className="input-cyber" value={form.ownerName} onChange={(e) => setForm({ ...form, ownerName: e.target.value })} />
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
