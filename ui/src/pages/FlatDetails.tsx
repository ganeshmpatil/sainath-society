import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Search, FileText, User, Calendar, Award, Plus, Download, Building2, Shield } from 'lucide-react'
import { flatDetails } from '../data/mockData'

export default function FlatDetails() {
  const { t } = useTranslation()
  const [searchTerm, setSearchTerm] = useState('')
  const [selectedFlat, setSelectedFlat] = useState<typeof flatDetails[0] | null>(null)

  const filteredFlats = flatDetails.filter(flat =>
    flat.flat.toLowerCase().includes(searchTerm.toLowerCase()) ||
    flat.ownerName.toLowerCase().includes(searchTerm.toLowerCase())
  )

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Building2 className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('flats.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('flats.description', 'Ownership, share certificates & documents')}</p>
        </div>
        <button className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('flats.addFlat', 'Add Flat')}
          </span>
        </button>
      </div>

      {/* Search */}
      <div className="glass-card p-5 mb-6">
        <div className="relative">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500" size={20} />
          <input
            type="text"
            placeholder={t('flats.searchPlaceholder', 'Search by flat number or owner name...')}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="input-cyber pl-12"
          />
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Flat List */}
        <div className="lg:col-span-1 space-y-4">
          {filteredFlats.map((flat) => (
            <div
              key={flat.id}
              onClick={() => setSelectedFlat(flat)}
              className={`glass-card p-5 cursor-pointer transition-all ${
                selectedFlat?.id === flat.id
                  ? 'ring-2 ring-purple-500 border-purple-500/50'
                  : 'hover:border-purple-500/30'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-semibold text-white text-lg">{t('flats.flatNumber', 'Flat')} {flat.flat}</h3>
                  <p className="text-sm text-slate-400">{t('flats.wing')} {flat.wing}, {t('flats.floor')} {flat.floor}</p>
                </div>
                <span className="px-3 py-1 text-xs bg-slate-700/50 text-slate-300 rounded-lg border border-slate-600/30">
                  {flat.area}
                </span>
              </div>
              <div className="mt-3 flex items-center gap-2">
                <User size={14} className="text-cyan-400" />
                <span className="text-sm text-slate-300">{flat.ownerName}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Flat Details */}
        <div className="lg:col-span-2">
          {selectedFlat ? (
            <div className="glass-card">
              <div className="p-6 border-b border-purple-500/20">
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold text-white font-display">{t('flats.flatNumber', 'Flat')} {selectedFlat.flat}</h2>
                    <p className="text-slate-400">{t('flats.wing')} {selectedFlat.wing}, {t('flats.floor')} {selectedFlat.floor} - {selectedFlat.area}</p>
                  </div>
                  <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                    {t('flats.editDetails', 'Edit Details')}
                  </button>
                </div>
              </div>

              <div className="p-6 space-y-6">
                {/* Ownership Details */}
                <div>
                  <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4 flex items-center gap-2">
                    <User size={16} className="text-purple-400" />
                    {t('flats.ownershipDetails', 'Ownership Details')}
                  </h3>
                  <div className="grid grid-cols-2 gap-4">
                    <div className="p-4 rounded-xl bg-slate-800/50 border border-slate-700/50">
                      <div className="flex items-center gap-2 text-slate-500 text-sm mb-2">
                        <User size={14} />
                        {t('flats.ownerName', 'Owner Name')}
                      </div>
                      <p className="font-semibold text-white">{selectedFlat.ownerName}</p>
                    </div>
                    <div className="p-4 rounded-xl bg-slate-800/50 border border-slate-700/50">
                      <div className="flex items-center gap-2 text-slate-500 text-sm mb-2">
                        <Calendar size={14} />
                        {t('flats.purchaseDate', 'Purchase Date')}
                      </div>
                      <p className="font-semibold text-white">{selectedFlat.purchaseDate}</p>
                    </div>
                  </div>
                </div>

                {/* Share Certificate */}
                <div>
                  <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4 flex items-center gap-2">
                    <Award size={16} className="text-cyan-400" />
                    {t('flats.shareCertificate', 'Share Certificate')}
                  </h3>
                  <div className="p-5 rounded-xl bg-gradient-to-r from-purple-500/10 to-cyan-500/10 border border-purple-500/20 flex items-center gap-4">
                    <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-purple-500 to-cyan-500 flex items-center justify-center">
                      <Award className="text-white" size={28} />
                    </div>
                    <div>
                      <p className="font-bold text-white text-lg">{t('flats.certificateNo', 'Certificate No')}: {selectedFlat.shareCertNo}</p>
                      <p className="text-sm text-emerald-400 flex items-center gap-1">
                        <Shield size={14} />
                        {t('flats.validRegistered', 'Valid and registered with the society')}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Nominee Details */}
                <div>
                  <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4">{t('flats.nomineeDetails', 'Nominee Details')}</h3>
                  <div className="p-4 rounded-xl bg-slate-800/50 border border-slate-700/50">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-semibold text-white">{selectedFlat.nomineeName}</p>
                        <p className="text-sm text-slate-400">{t('flats.relation', 'Relation')}: {selectedFlat.nomineeRelation}</p>
                      </div>
                      <button className="text-sm text-purple-400 hover:text-purple-300">{t('flats.updateNominee', 'Update Nominee')}</button>
                    </div>
                  </div>
                </div>

                {/* Documents */}
                <div>
                  <h3 className="text-sm font-semibold text-slate-400 uppercase tracking-wider mb-4 flex items-center gap-2">
                    <FileText size={16} className="text-emerald-400" />
                    {t('flats.documents', 'Documents')}
                  </h3>
                  <div className="space-y-2">
                    {selectedFlat.documents.map((doc, index) => (
                      <div key={index} className="flex items-center justify-between p-4 rounded-xl bg-slate-800/50 border border-slate-700/50 hover:border-purple-500/30 transition-colors">
                        <div className="flex items-center gap-3">
                          <FileText size={18} className="text-slate-400" />
                          <span className="text-white">{doc}</span>
                        </div>
                        <button className="p-2 text-cyan-400 hover:bg-cyan-500/10 rounded-lg transition-colors">
                          <Download size={18} />
                        </button>
                      </div>
                    ))}
                  </div>
                  <button className="mt-4 w-full py-3 border-2 border-dashed border-purple-500/30 text-purple-400 rounded-xl hover:border-purple-500/50 hover:bg-purple-500/5 transition-all">
                    + {t('flats.uploadDocument', 'Upload New Document')}
                  </button>
                </div>
              </div>
            </div>
          ) : (
            <div className="glass-card p-12 text-center">
              <FileText className="w-16 h-16 text-slate-700 mx-auto mb-4" />
              <p className="text-slate-500">{t('flats.selectFlat', 'Select a flat to view details')}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
