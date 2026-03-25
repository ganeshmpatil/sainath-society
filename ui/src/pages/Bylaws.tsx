import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { BookOpen, Search, Edit, Plus, ChevronDown, ChevronUp, Download, Scale } from 'lucide-react'
import { bylaws } from '../data/mockData'

export default function Bylaws() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [expandedSection, setExpandedSection] = useState('Membership')
  const [showModal, setShowModal] = useState(false)

  const sections = [...new Set(bylaws.map(b => b.section))]

  const filteredBylaws = bylaws.filter(bylaw =>
    bylaw.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    bylaw.content.toLowerCase().includes(searchTerm.toLowerCase()) ||
    bylaw.section.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const groupedBylaws = sections.reduce((acc, section) => {
    acc[section] = filteredBylaws.filter(b => b.section === section)
    return acc
  }, {} as Record<string, typeof bylaws>)

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Scale className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('bylaws.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('bylaws.rulesDescription', 'Rules and regulations governing the society')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('bylaws.addBylaw', 'Add Bylaw')}
          </span>
        </button>
      </div>

      {/* Search */}
      <div className="glass-card p-5 mb-6">
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
          <input
            type="text"
            placeholder={t('bylaws.searchPlaceholder', 'Search bylaws...')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="input-cyber pl-12"
          />
        </div>
      </div>

      {/* Quick Navigation */}
      <div className="flex flex-wrap gap-3 mb-6">
        {sections.map((section) => (
          <button
            key={section}
            onClick={() => setExpandedSection(section)}
            className={`px-5 py-2.5 rounded-xl text-sm font-semibold transition-all ${
              expandedSection === section
                ? 'bg-gradient-to-r from-purple-500 to-cyan-500 text-white shadow-lg'
                : 'glass-card text-slate-400 hover:text-white hover:border-purple-500/30'
            }`}
          >
            {section}
          </button>
        ))}
      </div>

      {/* Bylaws Accordion */}
      <div className="space-y-4">
        {sections.map((section) => {
          const sectionBylaws = groupedBylaws[section]
          if (!sectionBylaws || sectionBylaws.length === 0) return null

          const isExpanded = expandedSection === section

          return (
            <div key={section} className="glass-card overflow-hidden">
              <button
                onClick={() => setExpandedSection(isExpanded ? '' : section)}
                className="w-full flex items-center justify-between p-5 hover:bg-slate-800/30 transition-colors"
              >
                <div className="flex items-center gap-4">
                  <div className="p-3 rounded-xl bg-gradient-to-br from-purple-500/20 to-cyan-500/20 border border-purple-500/30">
                    <BookOpen size={22} className="text-purple-400" />
                  </div>
                  <div className="text-left">
                    <h3 className="font-semibold text-white text-lg">{section}</h3>
                    <p className="text-sm text-slate-500">{sectionBylaws.length} {t('bylaws.bylawsCount', 'bylaws')}</p>
                  </div>
                </div>
                {isExpanded ? (
                  <ChevronUp size={22} className="text-purple-400" />
                ) : (
                  <ChevronDown size={22} className="text-slate-500" />
                )}
              </button>

              {isExpanded && (
                <div className="border-t border-purple-500/20">
                  {sectionBylaws.map((bylaw, index) => (
                    <div
                      key={bylaw.id}
                      className={`p-6 ${index !== sectionBylaws.length - 1 ? 'border-b border-slate-800/50' : ''} hover:bg-slate-800/20 transition-colors`}
                    >
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex-1">
                          <div className="flex items-center gap-3 mb-3">
                            <span className="px-3 py-1 text-xs font-semibold bg-purple-500/20 text-purple-400 rounded-lg border border-purple-500/30">
                              {t('bylaws.article', 'Article')} {bylaw.id}
                            </span>
                          </div>
                          <h4 className="font-semibold text-white text-lg mb-2">{bylaw.title}</h4>
                          <p className="text-slate-400 leading-relaxed">{bylaw.content}</p>
                        </div>
                        <button className="p-2.5 text-slate-500 hover:text-purple-400 hover:bg-purple-500/10 rounded-xl transition-all">
                          <Edit size={18} />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {/* Download Section */}
      <div className="mt-8 rounded-2xl p-8 relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-purple-500/20 to-cyan-500/20" />
        <div className="absolute inset-0 border border-purple-500/30 rounded-2xl" />
        <div className="relative flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <h3 className="text-xl font-bold text-white font-display">{t('bylaws.downloadComplete', 'Download Complete Bylaws')}</h3>
            <p className="text-slate-400 mt-2">{t('bylaws.downloadDescription', 'Get the complete society bylaws document in PDF format')}</p>
          </div>
          <button className="cyber-button">
            <span className="flex items-center gap-2">
              <Download size={18} />
              {t('bylaws.download')}
            </span>
          </button>
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('bylaws.addNewBylaw', 'Add New Bylaw')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('bylaws.section')}</label>
                <select className="input-cyber">
                  {sections.map(section => (
                    <option key={section}>{section}</option>
                  ))}
                  <option>{t('bylaws.newSection', 'New Section')}</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('bylaws.titleLabel', 'Title')}</label>
                <input type="text" className="input-cyber" placeholder={t('bylaws.titlePlaceholder', 'Bylaw title')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('bylaws.content')}</label>
                <textarea rows={4} className="input-cyber" placeholder={t('bylaws.contentPlaceholder', 'Describe the bylaw in detail...')} />
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('bylaws.addBylaw', 'Add Bylaw')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
