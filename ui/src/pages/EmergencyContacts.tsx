import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Phone, Plus, Shield, Wrench, AlertTriangle, Users, Trash2, PhoneCall } from 'lucide-react'
import { useApi } from '../hooks/useApi'
import { emergencyContactsApi, EmergencyContact, Resident } from '../api/resources'
import { useAuth } from '../context/AuthContext'
import PageShell from '../components/PageShell'
import Modal from '../components/Modal'

const categoryIcons: Record<string, typeof Phone> = {
  COMMITTEE: Users,
  EMERGENCY: AlertTriangle,
  UTILITY: Wrench,
  OTHER: Phone,
}

const categoryColors: Record<string, string> = {
  COMMITTEE: 'purple',
  EMERGENCY: 'red',
  UTILITY: 'amber',
  OTHER: 'cyan',
}

// Default emergency numbers (India)
const defaultEmergencyNumbers = [
  { name: 'Police', nameMr: 'पोलीस', phone: '100', role: 'Emergency', roleMr: 'आणीबाणी' },
  { name: 'Fire Brigade', nameMr: 'अग्निशमन दल', phone: '101', role: 'Emergency', roleMr: 'आणीबाणी' },
  { name: 'Ambulance', nameMr: 'रुग्णवाहिका', phone: '108', role: 'Emergency', roleMr: 'आणीबाणी' },
  { name: 'Women Helpline', nameMr: 'महिला हेल्पलाइन', phone: '1091', role: 'Emergency', roleMr: 'आणीबाणी' },
  { name: 'Child Helpline', nameMr: 'बाल हेल्पलाइन', phone: '1098', role: 'Emergency', roleMr: 'आणीबाणी' },
  { name: 'Disaster Management', nameMr: 'आपत्ती व्यवस्थापन', phone: '1078', role: 'Emergency', roleMr: 'आणीबाणी' },
]

function CallButton({ phone, size = 'md' }: { phone: string; size?: 'sm' | 'md' }) {
  const paddings = size === 'sm' ? 'p-2' : 'p-2.5'
  return (
    <a
      href={`tel:${phone}`}
      className={`${paddings} rounded-xl bg-green-500/10 text-green-400 hover:bg-green-500/20 hover:text-green-300 transition-all border border-green-500/20 hover:border-green-500/40 inline-flex items-center gap-1.5`}
      title={`Call ${phone}`}
    >
      <PhoneCall size={size === 'sm' ? 14 : 16} />
      <span className="text-xs font-mono">{phone}</span>
    </a>
  )
}

export default function EmergencyContacts() {
  const { t, i18n } = useTranslation()
  const { isAdmin } = useAuth()
  const isMr = i18n.language === 'mr'
  const [modalOpen, setModalOpen] = useState(false)
  const [saving, setSaving] = useState(false)
  const [form, setForm] = useState({
    name: '', nameMr: '', category: 'UTILITY' as EmergencyContact['category'],
    phone: '', altPhone: '', role: '', roleMr: '', sortOrder: 0,
  })

  const { data, loading, error, reload } = useApi(() => emergencyContactsApi.list(), [])

  const contacts = data?.contacts ?? []
  const committee: Resident[] = data?.committee ?? []

  const handleCreate = async () => {
    setSaving(true)
    try {
      await emergencyContactsApi.create(form)
      setModalOpen(false)
      setForm({ name: '', nameMr: '', category: 'UTILITY', phone: '', altPhone: '', role: '', roleMr: '', sortOrder: 0 })
      reload()
    } catch (e) {
      alert((e as Error).message)
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (id: string) => {
    if (!confirm(t('common.confirm'))) return
    try {
      await emergencyContactsApi.delete(id)
      reload()
    } catch (e) {
      alert((e as Error).message)
    }
  }

  // Group contacts by category
  const grouped = contacts.reduce((acc, c) => {
    const cat = c.category || 'OTHER'
    if (!acc[cat]) acc[cat] = []
    acc[cat].push(c)
    return acc
  }, {} as Record<string, EmergencyContact[]>)

  return (
    <PageShell
      title={t('emergencyContacts.title')}
      subtitle={t('emergencyContacts.subtitle')}
      icon={Phone}
      loading={loading}
      error={error}
      onRetry={reload}
      actions={
        isAdmin && (
          <button onClick={() => setModalOpen(true)} className="cyber-button flex items-center gap-2 px-4 py-2">
            <Plus size={16} /> {t('emergencyContacts.addContact')}
          </button>
        )
      }
    >
      {/* Committee Members */}
      {committee.length > 0 && (
        <div className="mb-6">
          <h2 className="flex items-center gap-2 text-lg font-semibold text-purple-400 mb-3">
            <Shield size={18} />
            {t('emergencyContacts.committeeMembers')}
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {committee.map((m) => (
              <div key={m.id} className="glass-card p-4 hover:border-purple-500/40 transition-all">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h3 className="font-semibold text-white">{m.name}</h3>
                    <p className="text-xs text-purple-400 mt-0.5">
                      {m.designation || (m.role === 'ADMIN' ? t('login.admin') : t('residents.owner'))}
                    </p>
                    {m.flat && (
                      <p className="text-xs text-slate-500 mt-0.5">
                        {m.flat.flatNumber} {m.flat.wing?.name && `• ${t('flats.wing')} ${m.flat.wing.name}`}
                      </p>
                    )}
                  </div>
                  <CallButton phone={m.mobile} />
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Default Emergency Numbers */}
      <div className="mb-6">
        <h2 className="flex items-center gap-2 text-lg font-semibold text-red-400 mb-3">
          <AlertTriangle size={18} />
          {t('emergencyContacts.emergencyServices')}
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {defaultEmergencyNumbers.map((num) => (
            <div key={num.phone} className="glass-card p-4 hover:border-red-500/40 transition-all">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold text-white">{isMr ? num.nameMr : num.name}</h3>
                  <p className="text-xs text-red-400 mt-0.5">{isMr ? num.roleMr : num.role}</p>
                </div>
                <CallButton phone={num.phone} />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Custom contacts by category */}
      {(['UTILITY', 'OTHER'] as const).map((cat) => {
        const items = grouped[cat]
        if (!items || items.length === 0) return null
        const Icon = categoryIcons[cat]
        const color = categoryColors[cat]
        return (
          <div key={cat} className="mb-6">
            <h2 className={`flex items-center gap-2 text-lg font-semibold text-${color}-400 mb-3`}>
              <Icon size={18} />
              {t(`emergencyContacts.${cat.toLowerCase()}`)}
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {items.map((c) => (
                <div key={c.id} className={`glass-card p-4 hover:border-${color}-500/40 transition-all`}>
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1 min-w-0">
                      <h3 className="font-semibold text-white truncate">
                        {isMr && c.nameMr ? c.nameMr : c.name}
                      </h3>
                      {(c.role || c.roleMr) && (
                        <p className={`text-xs text-${color}-400 mt-0.5`}>
                          {isMr && c.roleMr ? c.roleMr : c.role}
                        </p>
                      )}
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      <CallButton phone={c.phone} size="sm" />
                      {isAdmin && (
                        <button
                          onClick={() => handleDelete(c.id)}
                          className="p-2 rounded-xl bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-all"
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  </div>
                  {c.altPhone && (
                    <div className="mt-2">
                      <CallButton phone={c.altPhone} size="sm" />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )
      })}

      {contacts.length === 0 && committee.length === 0 && (
        <div className="text-center text-slate-500 py-4 mt-2">
          {t('emergencyContacts.noCustomContacts')}
        </div>
      )}

      {/* Add Contact Modal */}
      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title={t('emergencyContacts.addContact')} size="lg">
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.name')} (EN)</label>
              <input className="input-cyber" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.name')} (MR)</label>
              <input className="input-cyber" value={form.nameMr} onChange={(e) => setForm({ ...form, nameMr: e.target.value })} />
            </div>
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.categoryLabel')}</label>
            <select className="input-cyber" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value as EmergencyContact['category'] })}>
              <option value="UTILITY">{t('emergencyContacts.utility')}</option>
              <option value="EMERGENCY">{t('emergencyContacts.emergency')}</option>
              <option value="OTHER">{t('emergencyContacts.other')}</option>
            </select>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.phone')}</label>
              <input className="input-cyber" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="9876543210" />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.altPhone')}</label>
              <input className="input-cyber" value={form.altPhone} onChange={(e) => setForm({ ...form, altPhone: e.target.value })} />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.roleLabel')} (EN)</label>
              <input className="input-cyber" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })} placeholder="e.g. Plumber, Electrician" />
            </div>
            <div>
              <label className="block text-sm text-slate-300 mb-1">{t('emergencyContacts.roleLabel')} (MR)</label>
              <input className="input-cyber" value={form.roleMr} onChange={(e) => setForm({ ...form, roleMr: e.target.value })} placeholder="उदा. प्लंबर, इलेक्ट्रिशियन" />
            </div>
          </div>
          <button onClick={handleCreate} disabled={saving || !form.name || !form.phone} className="cyber-button w-full">
            {saving ? t('common.loading') : t('common.save')}
          </button>
        </div>
      </Modal>
    </PageShell>
  )
}
