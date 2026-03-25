import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Lightbulb, ThumbsUp, Plus, Sparkles } from 'lucide-react'
import { suggestions } from '../data/mockData'

const statusConfig = {
  'Under Review': { color: 'bg-blue-500/20 text-blue-400 border-blue-500/30' },
  'Approved': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
  'Implemented': { color: 'bg-purple-500/20 text-purple-400 border-purple-500/30' },
  'Rejected': { color: 'bg-red-500/20 text-red-400 border-red-500/30' },
}

export default function Suggestions() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)

  const sortedSuggestions = [...suggestions].sort((a, b) => b.upvotes - a.upvotes)

  const getStatusText = (status: string) => {
    switch (status) {
      case 'Under Review': return t('suggestions.underReview', 'Under Review')
      case 'Approved': return t('suggestions.approved')
      case 'Implemented': return t('suggestions.implemented')
      case 'Rejected': return t('suggestions.rejected')
      default: return status
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Lightbulb className="w-6 h-6 text-yellow-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('suggestions.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('suggestions.description', 'Ideas and feedback from members')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('suggestions.newSuggestion')}
          </span>
        </button>
      </div>

      {/* Top Suggestions */}
      <div className="relative rounded-2xl p-8 mb-8 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-purple-500/20 via-cyan-500/20 to-pink-500/20" />
        <div className="absolute inset-0 border border-purple-500/30 rounded-2xl" />
        <div className="relative">
          <div className="flex items-center gap-2 mb-4">
            <Sparkles className="text-yellow-400" size={20} />
            <h2 className="text-lg font-semibold text-white">{t('suggestions.topVoted', 'Top Voted Suggestion')}</h2>
          </div>
          {sortedSuggestions[0] && (
            <div className="glass-card p-6">
              <div className="flex items-start gap-4">
                <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-yellow-400 to-orange-500 flex items-center justify-center">
                  <Lightbulb size={28} className="text-white" />
                </div>
                <div className="flex-1">
                  <h3 className="font-bold text-white text-xl">{sortedSuggestions[0].title}</h3>
                  <p className="text-slate-400 mt-2">{sortedSuggestions[0].description}</p>
                  <div className="flex items-center gap-6 mt-4">
                    <div className="flex items-center gap-2 text-yellow-400">
                      <ThumbsUp size={18} />
                      <span className="font-bold text-lg">{sortedSuggestions[0].upvotes} {t('suggestions.votes', 'votes')}</span>
                    </div>
                    <span className="text-slate-500">{t('suggestions.byFlat', 'by Flat')} {sortedSuggestions[0].flat}</span>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* All Suggestions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {sortedSuggestions.map((suggestion) => (
          <div key={suggestion.id} className="glass-card-hover p-6 group">
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-xl bg-purple-500/20 border border-purple-500/30 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform">
                <Lightbulb size={22} className="text-purple-400" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-3 mb-2">
                  <h3 className="font-semibold text-white truncate">{suggestion.title}</h3>
                </div>
                <span className={`inline-block px-3 py-1 text-xs font-semibold rounded-lg border ${statusConfig[suggestion.status as keyof typeof statusConfig]?.color}`}>
                  {getStatusText(suggestion.status)}
                </span>
                <p className="text-sm text-slate-400 mt-3 line-clamp-2">{suggestion.description}</p>

                <div className="flex items-center justify-between mt-5 pt-5 border-t border-slate-700/50">
                  <div className="flex items-center gap-4 text-sm text-slate-500">
                    <span>{t('suggestions.flatLabel', 'Flat')} <span className="text-purple-400">{suggestion.flat}</span></span>
                    <span>{suggestion.date}</span>
                  </div>
                  <button className="flex items-center gap-2 px-4 py-2 bg-purple-500/10 border border-purple-500/30 text-purple-400 rounded-xl hover:bg-purple-500/20 transition-all">
                    <ThumbsUp size={16} />
                    <span className="font-bold">{suggestion.upvotes}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('suggestions.submitSuggestion', 'Submit Suggestion')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('suggestions.titleLabel', 'Title')}</label>
                <input type="text" className="input-cyber" placeholder={t('suggestions.titlePlaceholder', 'Brief title for your suggestion')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('suggestions.description')}</label>
                <textarea rows={4} className="input-cyber" placeholder={t('suggestions.descriptionPlaceholder', 'Explain your suggestion in detail...')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('suggestions.category', 'Category')}</label>
                <select className="input-cyber">
                  <option>{t('suggestions.facilities', 'Facilities')}</option>
                  <option>{t('suggestions.security', 'Security')}</option>
                  <option>{t('suggestions.events', 'Events')}</option>
                  <option>{t('suggestions.environment', 'Environment')}</option>
                  <option>{t('suggestions.other', 'Other')}</option>
                </select>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('common.submit')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
