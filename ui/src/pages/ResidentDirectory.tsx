import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Search, Phone, Mail, Home, Filter, Users, Plus } from 'lucide-react'
import { residents } from '../data/mockData'

export default function ResidentDirectory() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [filterWing, setFilterWing] = useState('All')

  const filteredResidents = residents.filter(resident => {
    const matchesSearch = resident.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      resident.flat.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesWing = filterWing === 'All' || resident.wing === filterWing
    return matchesSearch && matchesWing
  })

  const wings = ['All', ...new Set(residents.map(r => r.wing))]

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Users className="w-6 h-6 text-cyan-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('residents.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('residents.viewAll')}</p>
        </div>
        <button className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('residents.addResident')}
          </span>
        </button>
      </div>

      {/* Filters */}
      <div className="glass-card p-5 mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
            <input
              type="text"
              placeholder={t('residents.searchPlaceholder')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-cyber pl-12"
            />
          </div>
          <div className="flex items-center gap-3">
            <Filter size={20} className="text-purple-400" />
            <select
              value={filterWing}
              onChange={(e) => setFilterWing(e.target.value)}
              className="input-cyber"
            >
              {wings.map(wing => (
                <option key={wing} value={wing}>
                  {wing === 'All' ? t('residents.allWings') : `${t('flats.wing')} ${wing}`}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Resident Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredResidents.map((resident) => (
          <div key={resident.id} className="glass-card-hover p-6 group">
            <div className="flex items-start gap-4">
              <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-purple-500 to-cyan-500 flex items-center justify-center group-hover:scale-110 transition-transform duration-300">
                <span className="text-white font-bold text-lg font-display">
                  {resident.name.split(' ').map(n => n[0]).join('')}
                </span>
              </div>
              <div className="flex-1">
                <h3 className="font-semibold text-white text-lg">{resident.name}</h3>
                <div className="flex items-center gap-2 mt-1">
                  <Home size={14} className="text-slate-500" />
                  <span className="text-sm text-slate-400">{resident.flat}</span>
                  <span className={`px-2 py-0.5 text-xs rounded-full ${
                    resident.status === 'Owner'
                      ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                      : 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                  }`}>
                    {resident.status === 'Owner' ? t('residents.owner') : t('residents.tenant')}
                  </span>
                </div>
              </div>
            </div>

            {resident.role !== 'Member' && (
              <div className="mt-4">
                <span className="px-3 py-1.5 text-xs font-semibold bg-gradient-to-r from-purple-500/20 to-cyan-500/20 text-purple-400 rounded-lg border border-purple-500/30">
                  {resident.role}
                </span>
              </div>
            )}

            <div className="mt-5 pt-5 border-t border-purple-500/20 space-y-3">
              <div className="flex items-center gap-3 text-sm text-slate-400">
                <Phone size={14} className="text-cyan-400" />
                {resident.phone}
              </div>
              <div className="flex items-center gap-3 text-sm text-slate-400">
                <Mail size={14} className="text-purple-400" />
                {resident.email}
              </div>
            </div>

            <div className="mt-5 flex gap-3">
              <button className="flex-1 py-2.5 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                {t('residents.viewProfile')}
              </button>
              <button className="flex-1 py-2.5 text-sm font-medium text-cyan-400 bg-cyan-500/10 border border-cyan-500/30 rounded-xl hover:bg-cyan-500/20 transition-all">
                {t('residents.contactBtn')}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
