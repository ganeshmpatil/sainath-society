import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Users, Search, Phone, Shield, Plus } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { residentsApi } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

export default function ResidentDirectory() {
  const { t } = useTranslation()
  const { isAdmin } = useAuth()
  const [search, setSearch] = useState('')
  const [modalOpen, setModalOpen] = useState(false)
  const [form, setForm] = useState({ name: '', mobile: '', designation: '' })
  const [saving, setSaving] = useState(false)

  const { data, loading, error, reload } = useApi(() => residentsApi.list({ activeOnly: true }), [])

  const filtered = (data?.residents ?? []).filter((r) => {
    const q = search.toLowerCase()
    return r.name.toLowerCase().includes(q) || (r.flat?.flatNumber ?? '').toLowerCase().includes(q)
  })

  const handleCreate = async () => {
    setSaving(true)
    try {
      await residentsApi.create(form)
      setModalOpen(false)
      setForm({ name: '', mobile: '', designation: '' })
      reload()
    } catch (e) {
      alert((e as Error).message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <PageShell
      title={t('residents.title')}
      subtitle={t('residents.viewAll')}
      icon={Users}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('residents.addResident')}
          </button>
        )
      }
    >
      <div className="glass-card p-4 mb-4 flex items-center gap-3">
        <Search className="w-5 h-5 text-slate-500" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder={t('residents.searchPlaceholder')}
          className="input-cyber flex-1"
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map((r) => (
          <div key={r.id} className="glass-card p-5 hover:border-purple-500/40 transition-all">
            <div className="flex items-start justify-between mb-3">
              <div>
                <h3 className="font-semibold text-white">{r.name}</h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  {r.flat?.flatNumber ?? '—'} {r.flat?.wing?.name && `• ${t('flats.wing')} ${r.flat.wing.name}`}
                </p>
              </div>
              {r.role === 'ADMIN' && (
                <span className="px-2 py-0.5 text-xs rounded-md bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 flex items-center gap-1">
                  <Shield size={10} /> {t('login.admin')}
                </span>
              )}
            </div>
            {r.designation && <p className="text-xs text-purple-400 mb-2">{r.designation}</p>}
            <div className="flex items-center gap-2 text-sm text-slate-400">
              <Phone size={14} />
              <span>{r.mobile}</span>
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <p className="col-span-full text-center text-slate-500 py-8">{t('common.noRecords')}</p>
        )}
      </div>

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('residents.addResident')}>
        <div className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('residents.name')}</label>
            <input className="input-cyber" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('residents.contact')}</label>
            <input className="input-cyber" value={form.mobile} onChange={(e) => setForm({ ...form, mobile: e.target.value })} />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('residents.designation')}</label>
            <input className="input-cyber" value={form.designation} onChange={(e) => setForm({ ...form, designation: e.target.value })} />
          </div>
          <button onClick={handleCreate} disabled={saving} className="cyber-button w-full">
            {saving ? t('common.loading') : t('common.save')}
          </button>
        </div>
      </Modal>
    </PageShell>
  )
}
