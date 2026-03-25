import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Search, Car, Bike, Plus, Tag, MapPin } from 'lucide-react'
import { vehicles } from '../data/mockData'

export default function Vehicles() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [filterType, setFilterType] = useState('All')
  const [showModal, setShowModal] = useState(false)

  const filteredVehicles = vehicles.filter(v => {
    const matchesSearch = v.number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      v.flat.toLowerCase().includes(searchTerm.toLowerCase()) ||
      v.make.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesType = filterType === 'All' || v.type === filterType
    return matchesSearch && matchesType
  })

  const carCount = vehicles.filter(v => v.type === 'Car').length
  const twoWheelerCount = vehicles.filter(v => v.type === 'Two Wheeler').length

  const getFilterLabel = (filter: string) => {
    switch (filter) {
      case 'All': return t('vehicles.allTypes', 'All Types')
      case 'Car': return t('vehicles.cars', 'Cars')
      case 'Two Wheeler': return t('vehicles.twoWheelers', 'Two Wheelers')
      default: return filter
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Car className="w-6 h-6 text-cyan-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('vehicles.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('vehicles.description', 'Manage society vehicle records')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('vehicles.registerVehicle')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-blue-500/20 border border-blue-500/30">
              <Car size={24} className="text-blue-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{vehicles.length}</p>
              <p className="text-sm text-slate-400">{t('vehicles.total', 'Total')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/30">
              <Car size={24} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{carCount}</p>
              <p className="text-sm text-slate-400">{t('vehicles.car')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-orange-500/20 border border-orange-500/30">
              <Bike size={24} className="text-orange-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{twoWheelerCount}</p>
              <p className="text-sm text-slate-400">{t('vehicles.bike')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="glass-card p-5 mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
            <input
              type="text"
              placeholder={t('vehicles.searchPlaceholder', 'Search by number, flat or make...')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-cyber pl-12"
            />
          </div>
          <select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            className="input-cyber w-auto"
          >
            <option value="All">{t('vehicles.allTypes', 'All Types')}</option>
            <option value="Car">{t('vehicles.cars', 'Cars')}</option>
            <option value="Two Wheeler">{t('vehicles.twoWheelers', 'Two Wheelers')}</option>
          </select>
        </div>
      </div>

      {/* Vehicle List */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {filteredVehicles.map((vehicle) => (
          <div key={vehicle.id} className="glass-card-hover p-6 group">
            <div className="flex items-start gap-4">
              <div className={`p-4 rounded-xl ${vehicle.type === 'Car' ? 'bg-blue-500/20 border border-blue-500/30' : 'bg-orange-500/20 border border-orange-500/30'} group-hover:scale-110 transition-transform`}>
                {vehicle.type === 'Car' ? (
                  <Car size={28} className="text-blue-400" />
                ) : (
                  <Bike size={28} className="text-orange-400" />
                )}
              </div>
              <div className="flex-1">
                <h3 className="font-bold text-white text-xl font-display">{vehicle.number}</h3>
                <p className="text-slate-400">{vehicle.make}</p>
              </div>
            </div>

            <div className="mt-5 space-y-3">
              <div className="flex items-center gap-3 text-sm">
                <MapPin size={16} className="text-purple-400" />
                <span className="text-slate-400">{t('vehicles.flat')}: <span className="text-white">{vehicle.flat}</span></span>
              </div>
              <div className="flex items-center gap-3 text-sm">
                <Tag size={16} className="text-cyan-400" />
                <span className="text-slate-400">{t('vehicles.parking', 'Parking')}: <span className="text-white">{vehicle.parkingSlot}</span></span>
              </div>
              <div className="flex items-center gap-3 text-sm">
                <div className="w-3 h-3 bg-emerald-500 rounded-full animate-pulse" />
                <span className="text-slate-400">{t('vehicles.sticker')}: <span className="text-emerald-400">{vehicle.stickerNo}</span></span>
              </div>
            </div>

            <div className="mt-5 flex gap-3">
              <button className="flex-1 py-2.5 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                {t('common.edit')}
              </button>
              <button className="flex-1 py-2.5 text-sm font-medium text-red-400 bg-red-500/10 border border-red-500/30 rounded-xl hover:bg-red-500/20 transition-all">
                {t('vehicles.remove', 'Remove')}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('vehicles.registerVehicle')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('vehicles.vehicleType', 'Vehicle Type')}</label>
                  <select className="input-cyber">
                    <option>{t('vehicles.car')}</option>
                    <option>{t('vehicles.twoWheeler', 'Two Wheeler')}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('flats.flatNumber')}</label>
                  <input type="text" className="input-cyber" placeholder="A-101" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('vehicles.vehicleNumber')}</label>
                <input type="text" className="input-cyber" placeholder="MH-02-AB-1234" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('vehicles.makeModel', 'Make/Model')}</label>
                <input type="text" className="input-cyber" placeholder={t('vehicles.makeModelPlaceholder', 'Honda City')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('vehicles.parkingSlot')}</label>
                  <input type="text" className="input-cyber" placeholder="P-01" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('vehicles.stickerNumber', 'Sticker Number')}</label>
                  <input type="text" className="input-cyber" placeholder="STK-001" />
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('vehicles.register', 'Register')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
