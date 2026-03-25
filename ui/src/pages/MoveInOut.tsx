import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ArrowLeftRight, Plus, Home, User, Calendar, Shield, CheckCircle, Clock, FileText } from 'lucide-react'
import { moveInOut } from '../data/mockData'

const statusConfig = {
  'Completed': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
  'In Progress': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' },
  'Pending': { color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
}

const typeConfig = {
  'Move In': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', icon: Home },
  'Move Out': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: Home },
}

export default function MoveInOut() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)
  const [filterType, setFilterType] = useState('All')

  const filteredRecords = moveInOut.filter(record =>
    filterType === 'All' || record.type === filterType
  )

  const moveInCount = moveInOut.filter(r => r.type === 'Move In').length
  const moveOutCount = moveInOut.filter(r => r.type === 'Move Out').length
  const pendingVerifications = moveInOut.filter(r => r.policeVerification === 'Pending').length

  const getTypeText = (type: string) => {
    switch (type) {
      case 'Move In': return t('moveInOut.moveIn')
      case 'Move Out': return t('moveInOut.moveOut')
      default: return type
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'Completed': return t('tasks.completed')
      case 'In Progress': return t('grievances.inProgress')
      case 'Pending': return t('moveInOut.pending')
      default: return status
    }
  }

  const getFilterText = (filter: string) => {
    switch (filter) {
      case 'All': return t('common.all')
      case 'Move In': return t('moveInOut.moveIn')
      case 'Move Out': return t('moveInOut.moveOut')
      default: return filter
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <ArrowLeftRight className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('moveInOut.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('moveInOut.description', 'Manage tenant movements and documentation')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('moveInOut.newEntry', 'New Entry')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 border border-purple-500/30">
              <ArrowLeftRight size={24} className="text-purple-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{moveInOut.length}</p>
              <p className="text-sm text-slate-400">{t('moveInOut.totalRecords', 'Total Records')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/30">
              <Home size={24} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-emerald-400 font-display">{moveInCount}</p>
              <p className="text-sm text-slate-400">{t('moveInOut.moveIn')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-red-500/20 border border-red-500/30">
              <Home size={24} className="text-red-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-red-400 font-display">{moveOutCount}</p>
              <p className="text-sm text-slate-400">{t('moveInOut.moveOut')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-yellow-500/20 border border-yellow-500/30">
              <Shield size={24} className="text-yellow-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-yellow-400 font-display">{pendingVerifications}</p>
              <p className="text-sm text-slate-400">{t('moveInOut.pendingVerification', 'Pending Verification')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filter */}
      <div className="glass-card p-5 mb-6">
        <div className="flex gap-3">
          {['All', 'Move In', 'Move Out'].map((type) => (
            <button
              key={type}
              onClick={() => setFilterType(type)}
              className={`px-5 py-2.5 rounded-xl text-sm font-semibold transition-all ${
                filterType === type
                  ? 'bg-gradient-to-r from-purple-500 to-cyan-500 text-white shadow-lg'
                  : 'bg-slate-800/50 text-slate-400 hover:text-white border border-slate-700/50 hover:border-purple-500/30'
              }`}
            >
              {getFilterText(type)}
            </button>
          ))}
        </div>
      </div>

      {/* Records */}
      <div className="space-y-4">
        {filteredRecords.map((record) => (
          <div key={record.id} className="glass-card-hover p-6">
            <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
              <div className="flex-1">
                <div className="flex items-center gap-3 mb-4">
                  <span className={`px-4 py-1.5 text-sm font-semibold rounded-lg border ${typeConfig[record.type as keyof typeof typeConfig]?.color}`}>
                    {getTypeText(record.type)}
                  </span>
                  <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${statusConfig[record.status as keyof typeof statusConfig]?.color}`}>
                    {getStatusText(record.status)}
                  </span>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1 flex items-center gap-1">
                      <Home size={12} /> {t('moveInOut.flat')}
                    </p>
                    <p className="font-semibold text-white">{record.flat}</p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1 flex items-center gap-1">
                      <User size={12} /> {t('moveInOut.tenant', 'Tenant')}
                    </p>
                    <p className="font-semibold text-white">{record.tenantName}</p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1 flex items-center gap-1">
                      <User size={12} /> {t('moveInOut.owner', 'Owner')}
                    </p>
                    <p className="font-semibold text-white">{record.ownerName}</p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1 flex items-center gap-1">
                      <Calendar size={12} /> {getTypeText(record.type)} {t('moveInOut.date')}
                    </p>
                    <p className="font-semibold text-white">{record.date}</p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1 flex items-center gap-1">
                      <Clock size={12} /> {t('moveInOut.agreementEnd', 'Agreement End')}
                    </p>
                    <p className="font-semibold text-white">{record.agreementEndDate}</p>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <p className="text-xs text-slate-500 mb-1">{t('moveInOut.securityDeposit', 'Security Deposit')}</p>
                    <p className="font-semibold text-cyan-400">₹{record.securityDeposit.toLocaleString()}</p>
                  </div>
                </div>

                <div className="mt-4 flex items-center gap-3 p-3 rounded-xl bg-slate-800/30 border border-slate-700/30">
                  <Shield size={18} className={record.policeVerification === 'Done' ? 'text-emerald-400' : 'text-yellow-400'} />
                  <span className={`text-sm font-medium ${
                    record.policeVerification === 'Done' ? 'text-emerald-400' :
                    record.policeVerification === 'Pending' ? 'text-yellow-400' : 'text-slate-400'
                  }`}>
                    {t('moveInOut.policeVerification', 'Police Verification')}: {record.policeVerification === 'Done' ? t('moveInOut.done', 'Done') : record.policeVerification === 'Pending' ? t('moveInOut.pending') : record.policeVerification}
                  </span>
                  {record.policeVerification === 'Done' && (
                    <CheckCircle size={16} className="text-emerald-400" />
                  )}
                </div>
              </div>

              <div className="flex gap-2">
                <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                  {t('moveInOut.viewDetails', 'View Details')}
                </button>
                <button className="px-4 py-2 text-sm font-medium text-cyan-400 bg-cyan-500/10 border border-cyan-500/30 rounded-xl hover:bg-cyan-500/20 transition-all flex items-center gap-2">
                  <FileText size={14} />
                  {t('moveInOut.documents', 'Documents')}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('moveInOut.newMoveEntry', 'New Move In/Out Entry')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.type')}</label>
                <select className="input-cyber">
                  <option>{t('moveInOut.moveIn')}</option>
                  <option>{t('moveInOut.moveOut')}</option>
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('flats.flatNumber')}</label>
                  <input type="text" className="input-cyber" placeholder="A-101" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.date')}</label>
                  <input type="date" className="input-cyber" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.tenantName', 'Tenant Name')}</label>
                <input type="text" className="input-cyber" placeholder={t('moveInOut.enterTenantName', 'Enter tenant name')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.ownerName', 'Owner Name')}</label>
                <input type="text" className="input-cyber" placeholder={t('moveInOut.enterOwnerName', 'Enter owner name')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.securityDeposit', 'Security Deposit')}</label>
                  <input type="number" className="input-cyber" placeholder="50000" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.agreementEndDate', 'Agreement End Date')}</label>
                  <input type="date" className="input-cyber" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('moveInOut.policeVerificationStatus', 'Police Verification Status')}</label>
                <select className="input-cyber">
                  <option>{t('moveInOut.pending')}</option>
                  <option>{t('moveInOut.done', 'Done')}</option>
                  <option>{t('moveInOut.notApplicable', 'N/A')}</option>
                </select>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('moveInOut.saveEntry', 'Save Entry')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
