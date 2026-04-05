import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Package, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { inventoryApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const CONDITIONS = ['NEW', 'GOOD', 'FAIR', 'POOR', 'NEEDS_REPAIR', 'SCRAPPED']

export default function Inventory() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    name: '', nameMr: '', category: '', quantity: 1, unitPrice: 0, condition: 'GOOD', location: '',
  })

  const { data, loading, error, reload } = useApi(() => inventoryApi.list(), [])

  const create = async () => {
    try {
      await inventoryApi.create(form)
      setModalOpen(false)
      setForm({ name: '', nameMr: '', category: '', quantity: 1, unitPrice: 0, condition: 'GOOD', location: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('inventory.title')}
      icon={Package}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('inventory.addItem')}
          </button>
        )
      }
    >
      <div className="glass-card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-800/50 text-slate-400 uppercase text-xs">
            <tr>
              <th className="text-left px-4 py-3">{t('inventory.itemName')}</th>
              <th className="text-left px-4 py-3">{t('inventory.category')}</th>
              <th className="text-left px-4 py-3">{t('inventory.quantity')}</th>
              <th className="text-left px-4 py-3">{t('inventory.unitPrice')}</th>
              <th className="text-left px-4 py-3">{t('inventory.totalValue')}</th>
              <th className="text-left px-4 py-3">{t('inventory.condition')}</th>
              <th className="text-left px-4 py-3">{t('inventory.location')}</th>
            </tr>
          </thead>
          <tbody>
            {(data?.items ?? []).map((i) => (
              <tr key={i.id} className="border-t border-purple-500/10 hover:bg-slate-800/30">
                <td className="px-4 py-3 font-medium text-white">{isMr && i.nameMr ? i.nameMr : i.name}</td>
                <td className="px-4 py-3 text-slate-300">{i.category}</td>
                <td className="px-4 py-3 text-slate-300">{i.quantity}</td>
                <td className="px-4 py-3 text-slate-300">₹{i.unitPrice.toLocaleString()}</td>
                <td className="px-4 py-3 text-white font-semibold">₹{i.totalValue.toLocaleString()}</td>
                <td className="px-4 py-3">
                  <span className="px-2 py-0.5 text-xs rounded border bg-cyan-500/10 text-cyan-400 border-cyan-500/30">
                    {t(`inventory.${i.condition.toLowerCase().replace('_', '')}`, i.condition)}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-400">{i.location ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('inventory.addItem')} size="lg">
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.itemName')} (EN)</label>
              <input className="input-cyber" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.itemName')} (मराठी)</label>
              <input className="input-cyber" value={form.nameMr} onChange={(e) => setForm({ ...form, nameMr: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.category')}</label>
              <input className="input-cyber" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.location')}</label>
              <input className="input-cyber" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.quantity')}</label>
              <input type="number" className="input-cyber" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.unitPrice')}</label>
              <input type="number" className="input-cyber" value={form.unitPrice} onChange={(e) => setForm({ ...form, unitPrice: +e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('inventory.condition')}</label>
              <select className="input-cyber" value={form.condition} onChange={(e) => setForm({ ...form, condition: e.target.value })}>
                {CONDITIONS.map((c) => <option key={c} value={c}>{t(`inventory.${c.toLowerCase().replace('_', '')}`, c)}</option>)}
              </select>
            </div>
          </div>
          <button onClick={create} className="cyber-button w-full">{t('common.save')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
