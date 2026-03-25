import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Bell, Plus, Calendar, AlertTriangle, Info, Megaphone, Radio } from 'lucide-react'
import { notices } from '../data/mockData'

const typeConfig = {
  'Maintenance': { color: 'bg-orange-500/20 text-orange-400 border-orange-500/30', icon: AlertTriangle },
  'Meeting': { color: 'bg-blue-500/20 text-blue-400 border-blue-500/30', icon: Calendar },
  'Event': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30', icon: Megaphone },
  'Finance': { color: 'bg-red-500/20 text-red-400 border-red-500/30', icon: Info },
}

const priorityBorders = {
  'Critical': 'border-l-red-500',
  'High': 'border-l-orange-500',
  'Normal': 'border-l-cyan-500',
}

export default function Notices() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)
  const [selectedNotice, setSelectedNotice] = useState<typeof notices[0] | null>(null)

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Radio className="w-6 h-6 text-cyan-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('notices.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('notices.description', 'Digital noticeboard for society communications')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('notices.postNotice', 'Post Notice')}
          </span>
        </button>
      </div>

      {/* Notice Categories */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {Object.entries(typeConfig).map(([type, config]) => {
          const count = notices.filter(n => n.type === type).length
          const Icon = config.icon
          return (
            <div key={type} className="stat-card cursor-pointer group">
              <div className="flex items-center gap-4">
                <div className={`p-3 rounded-xl border ${config.color} group-hover:scale-110 transition-transform`}>
                  <Icon size={22} />
                </div>
                <div>
                  <p className="text-2xl font-bold text-white font-display">{count}</p>
                  <p className="text-sm text-slate-400">{type}</p>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Notices */}
      <div className="space-y-4">
        {notices.map((notice) => {
          const TypeIcon = typeConfig[notice.type as keyof typeof typeConfig]?.icon || Bell
          return (
            <div
              key={notice.id}
              className={`glass-card-hover p-6 border-l-4 ${priorityBorders[notice.priority as keyof typeof priorityBorders]} cursor-pointer`}
              onClick={() => setSelectedNotice(notice)}
            >
              <div className="flex items-start gap-4">
                <div className={`p-3 rounded-xl border ${typeConfig[notice.type as keyof typeof typeConfig]?.color || 'bg-slate-700/50 text-slate-400'}`}>
                  <TypeIcon size={22} />
                </div>
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-2">
                    <h3 className="font-semibold text-white text-lg">{notice.title}</h3>
                    {notice.priority === 'Critical' && (
                      <span className="px-2 py-0.5 text-xs bg-red-500/20 text-red-400 border border-red-500/30 rounded-full animate-pulse">
                        {t('notices.urgent')}
                      </span>
                    )}
                  </div>
                  <p className="text-sm text-slate-400 line-clamp-2">{notice.content}</p>
                  <div className="flex items-center gap-4 mt-4 text-sm">
                    <span className={`px-3 py-1 rounded-lg border ${typeConfig[notice.type as keyof typeof typeConfig]?.color || 'bg-slate-700/50 text-slate-400'}`}>
                      {notice.type}
                    </span>
                    <span className="text-slate-500">{notice.date}</span>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* View Notice Modal */}
      {selectedNotice && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <div className="flex items-center gap-3">
                <span className={`px-3 py-1 text-xs rounded-lg border ${typeConfig[selectedNotice.type as keyof typeof typeConfig]?.color}`}>
                  {selectedNotice.type}
                </span>
                {selectedNotice.priority === 'Critical' && (
                  <span className="px-2 py-0.5 text-xs bg-red-500/20 text-red-400 border border-red-500/30 rounded-full">
                    {t('notices.urgent')}
                  </span>
                )}
              </div>
              <h2 className="text-xl font-bold text-white mt-3 font-display">{selectedNotice.title}</h2>
              <p className="text-sm text-slate-500 mt-1">{t('notices.postedOn')} {selectedNotice.date}</p>
            </div>
            <div className="p-6">
              <p className="text-slate-300 whitespace-pre-wrap leading-relaxed">{selectedNotice.content}</p>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end">
              <button onClick={() => setSelectedNotice(null)} className="cyber-button">
                <span>{t('common.close')}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Post Notice Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('notices.postNewNotice', 'Post New Notice')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('notices.titleLabel', 'Title')}</label>
                <input type="text" className="input-cyber" placeholder={t('notices.titlePlaceholder', 'Notice title')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('notices.content')}</label>
                <textarea rows={5} className="input-cyber" placeholder={t('notices.contentPlaceholder', 'Notice details...')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('notices.type', 'Type')}</label>
                  <select className="input-cyber">
                    {Object.keys(typeConfig).map(type => (
                      <option key={type}>{type}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('notices.priority', 'Priority')}</label>
                  <select className="input-cyber">
                    <option>{t('notices.normal', 'Normal')}</option>
                    <option>{t('notices.high', 'High')}</option>
                    <option>{t('notices.critical', 'Critical')}</option>
                  </select>
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('notices.postNotice', 'Post Notice')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
