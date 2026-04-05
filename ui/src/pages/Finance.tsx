import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { DollarSign, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { billsApi, MaintenanceBill } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const STATUS_COLORS: Record<string, string> = {
  PAID: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30',
  ISSUED: 'bg-blue-500/10 text-blue-400 border-blue-500/30',
  OVERDUE: 'bg-red-500/10 text-red-400 border-red-500/30',
  DRAFT: 'bg-slate-500/10 text-slate-400 border-slate-500/30',
  WAIVED: 'bg-purple-500/10 text-purple-400 border-purple-500/30',
}

export default function Finance() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({
    billingPeriod: new Date().toISOString().slice(0, 7),
    dueDate: new Date(Date.now() + 30 * 864e5).toISOString().slice(0, 10),
    maintenanceCharge: 2500,
    sinkingFund: 500,
    repairFund: 0,
    waterCharge: 300,
    otherCharges: 0,
  })

  const bills = useApi(() => billsApi.list(), [])
  const dues = useApi(() => billsApi.pendingDues(), [])

  const generate = async () => {
    try {
      const res = await billsApi.generate({
        billingPeriod: form.billingPeriod,
        dueDate: new Date(form.dueDate).toISOString(),
        maintenanceCharge: form.maintenanceCharge,
        sinkingFund: form.sinkingFund,
        repairFund: form.repairFund,
        waterCharge: form.waterCharge,
        otherCharges: form.otherCharges,
      })
      alert(`${t('common.success')}: ${res.created} ${t('finance.issued')}, ${res.skipped} skipped`)
      setModalOpen(false)
      bills.reload()
      dues.reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  const markPaid = async (b: MaintenanceBill) => {
    try {
      await billsApi.markPaid(b.id, b.totalAmount - b.amountPaid)
      bills.reload()
      dues.reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  return (
    <PageShell
      title={t('finance.title')}
      icon={DollarSign}
      loading={bills.loading}
      error={bills.error}
      onRetry={bills.reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('finance.generateBills')}
          </button>
        )
      }
    >
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="stat-card">
          <p className="text-sm text-slate-400 uppercase">{t('finance.pendingDues')}</p>
          <p className="text-2xl font-bold text-red-400 mt-2">₹{(dues.data?.pendingAmount ?? 0).toLocaleString()}</p>
        </div>
        <div className="stat-card">
          <p className="text-sm text-slate-400 uppercase">{t('finance.pending')}</p>
          <p className="text-2xl font-bold text-orange-400 mt-2">{dues.data?.unpaidCount ?? 0}</p>
        </div>
        <div className="stat-card">
          <p className="text-sm text-slate-400 uppercase">{t('common.total')} {t('finance.maintenanceBills')}</p>
          <p className="text-2xl font-bold text-purple-400 mt-2">{bills.data?.count ?? 0}</p>
        </div>
      </div>

      <div className="glass-card overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-slate-800/50 text-slate-400 uppercase text-xs">
            <tr>
              <th className="text-left px-4 py-3">{t('finance.billNo')}</th>
              <th className="text-left px-4 py-3">{t('finance.billingPeriod')}</th>
              <th className="text-left px-4 py-3">{t('flats.flatNumber')}</th>
              <th className="text-left px-4 py-3">{t('finance.amount')}</th>
              <th className="text-left px-4 py-3">{t('finance.dueDate')}</th>
              <th className="text-left px-4 py-3">{t('finance.status')}</th>
              {isAdmin && <th className="px-4 py-3">{t('common.actions')}</th>}
            </tr>
          </thead>
          <tbody>
            {(bills.data?.bills ?? []).map((b) => (
              <tr key={b.id} className="border-t border-purple-500/10 hover:bg-slate-800/30">
                <td className="px-4 py-3 font-mono text-xs text-slate-300">{b.billNo}</td>
                <td className="px-4 py-3 text-slate-300">{b.billingPeriod}</td>
                <td className="px-4 py-3 text-white">{b.flat?.flatNumber ?? '—'}</td>
                <td className="px-4 py-3 text-white font-semibold">₹{b.totalAmount.toLocaleString()}</td>
                <td className="px-4 py-3 text-slate-300">{new Date(b.dueDate).toLocaleDateString()}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 text-xs rounded border ${STATUS_COLORS[b.status]}`}>
                    {t(`finance.${b.status.toLowerCase()}`, b.status)}
                  </span>
                </td>
                {isAdmin && (
                  <td className="px-4 py-3">
                    {b.status !== 'PAID' && (
                      <button onClick={() => markPaid(b)} className="text-xs text-emerald-400 hover:text-emerald-300">
                        {t('finance.markPaid')}
                      </button>
                    )}
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
        {bills.data?.count === 0 && <p className="text-center text-slate-500 py-8">{t('common.noRecords')}</p>}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('finance.generateBills')} size="lg">
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('finance.billingPeriod')}</label>
              <input type="month" className="input-cyber" value={form.billingPeriod} onChange={(e) => setForm({ ...form, billingPeriod: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('finance.dueDate')}</label>
              <input type="date" className="input-cyber" value={form.dueDate} onChange={(e) => setForm({ ...form, dueDate: e.target.value })} />
            </div>
          </div>
          {(['maintenanceCharge', 'sinkingFund', 'repairFund', 'waterCharge', 'otherCharges'] as const).map((k) => (
            <div key={k}>
              <label className="block text-sm text-slate-300 mb-1">{t(`finance.${k}`)}</label>
              <input type="number" className="input-cyber" value={form[k]} onChange={(e) => setForm({ ...form, [k]: +e.target.value })} />
            </div>
          ))}
          <button onClick={generate} className="cyber-button w-full">{t('finance.generateBills')}</button>
        </div>
      </Modal>
    </PageShell>
  )
}
