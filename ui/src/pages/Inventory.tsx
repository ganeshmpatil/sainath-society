import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Package, Plus, Search, MapPin, CheckCircle, AlertTriangle, Wrench } from 'lucide-react'
import { inventory } from '../data/mockData'

const conditionConfig = {
  'Good': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', icon: CheckCircle },
  'Fair': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30', icon: AlertTriangle },
  'Poor': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: Wrench },
}

export default function Inventory() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [showModal, setShowModal] = useState(false)

  const filteredInventory = inventory.filter(item =>
    item.item.toLowerCase().includes(searchTerm.toLowerCase()) ||
    item.location.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const totalItems = inventory.reduce((sum, item) => sum + item.quantity, 0)
  const goodCondition = inventory.filter(i => i.condition === 'Good').length
  const needsAttention = inventory.filter(i => i.condition !== 'Good').length

  const getConditionText = (condition: string) => {
    switch (condition) {
      case 'Good': return t('inventory.good', 'Good')
      case 'Fair': return t('inventory.fair', 'Fair')
      case 'Poor': return t('inventory.poor', 'Poor')
      default: return condition
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Package className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('inventory.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('inventory.description', 'Track society assets and equipment')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('inventory.addItem')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 border border-purple-500/30">
              <Package size={24} className="text-purple-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{inventory.length}</p>
              <p className="text-sm text-slate-400">{t('inventory.itemCategories', 'Item Categories')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-blue-500/20 border border-blue-500/30">
              <Package size={24} className="text-blue-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{totalItems}</p>
              <p className="text-sm text-slate-400">{t('inventory.totalQuantity', 'Total Quantity')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/30">
              <CheckCircle size={24} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-emerald-400 font-display">{goodCondition}</p>
              <p className="text-sm text-slate-400">{t('inventory.goodCondition', 'Good Condition')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-yellow-500/20 border border-yellow-500/30">
              <AlertTriangle size={24} className="text-yellow-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-yellow-400 font-display">{needsAttention}</p>
              <p className="text-sm text-slate-400">{t('inventory.needsAttention', 'Needs Attention')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Search */}
      <div className="glass-card p-5 mb-6">
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
          <input
            type="text"
            placeholder={t('inventory.searchPlaceholder', 'Search inventory...')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="input-cyber pl-12"
          />
        </div>
      </div>

      {/* Inventory Table */}
      <div className="glass-card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-purple-500/20 text-left text-sm text-slate-400">
                <th className="px-6 py-4 font-medium">{t('inventory.itemName')}</th>
                <th className="px-6 py-4 font-medium">{t('inventory.quantity')}</th>
                <th className="px-6 py-4 font-medium">{t('inventory.location')}</th>
                <th className="px-6 py-4 font-medium">{t('inventory.condition', 'Condition')}</th>
                <th className="px-6 py-4 font-medium">{t('inventory.lastUpdated')}</th>
                <th className="px-6 py-4 font-medium">{t('common.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {filteredInventory.map((item) => (
                <tr key={item.id} className="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="p-2.5 rounded-xl bg-purple-500/10 border border-purple-500/20">
                        <Package size={18} className="text-purple-400" />
                      </div>
                      <span className="font-medium text-white">{item.item}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className="font-bold text-white text-lg">{item.quantity}</span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-2 text-sm text-slate-300">
                      <MapPin size={14} className="text-cyan-400" />
                      {item.location}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${conditionConfig[item.condition as keyof typeof conditionConfig]?.color}`}>
                      {getConditionText(item.condition)}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-slate-400">
                    {item.lastChecked}
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2">
                      <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                        {t('common.edit')}
                      </button>
                      <button className="px-4 py-2 text-sm font-medium text-cyan-400 bg-cyan-500/10 border border-cyan-500/30 rounded-xl hover:bg-cyan-500/20 transition-all">
                        {t('inventory.check', 'Check')}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('inventory.addInventoryItem', 'Add Inventory Item')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('inventory.itemName')}</label>
                <input type="text" className="input-cyber" placeholder={t('inventory.itemNamePlaceholder', 'e.g., Folding Chairs')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('inventory.quantity')}</label>
                  <input type="number" className="input-cyber" placeholder="10" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('inventory.condition', 'Condition')}</label>
                  <select className="input-cyber">
                    <option>{t('inventory.good', 'Good')}</option>
                    <option>{t('inventory.fair', 'Fair')}</option>
                    <option>{t('inventory.poor', 'Poor')}</option>
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('inventory.location')}</label>
                <input type="text" className="input-cyber" placeholder={t('inventory.locationPlaceholder', 'e.g., Hall Store Room')} />
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('inventory.addItem')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
