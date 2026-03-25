import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { DollarSign, TrendingUp, TrendingDown, AlertCircle, Download, PieChart, Wallet } from 'lucide-react'
import { financials } from '../data/mockData'

export default function Finance() {
  const { t } = useTranslation()
  const [activeTab, setActiveTab] = useState('overview')

  const getTabLabel = (tab: string) => {
    switch (tab) {
      case 'overview': return t('finance.overview', 'Overview')
      case 'income': return t('finance.income', 'Income')
      case 'expenses': return t('finance.expenses')
      case 'pending': return t('finance.pending')
      default: return tab
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Wallet className="w-6 h-6 text-emerald-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('finance.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('finance.description', 'Society financial management and transparency')}</p>
        </div>
        <button className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Download size={18} />
            {t('finance.exportReport', 'Export Report')}
          </span>
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4 mb-8">
        <div className="stat-card relative overflow-hidden group">
          <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/10 to-transparent" />
          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              <TrendingUp size={18} className="text-emerald-400" />
              <span className="text-xs text-slate-400 uppercase tracking-wider">{t('finance.collection', 'Collection')}</span>
            </div>
            <p className="text-2xl font-bold text-emerald-400 font-display">₹{(financials.summary.totalCollection / 100000).toFixed(1)}L</p>
          </div>
        </div>
        <div className="stat-card relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-red-500/10 to-transparent" />
          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              <AlertCircle size={18} className="text-red-400" />
              <span className="text-xs text-slate-400 uppercase tracking-wider">{t('finance.pending')}</span>
            </div>
            <p className="text-2xl font-bold text-red-400 font-display">₹{(financials.summary.pendingDues / 1000).toFixed(0)}K</p>
          </div>
        </div>
        <div className="stat-card relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-blue-500/10 to-transparent" />
          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              <TrendingDown size={18} className="text-blue-400" />
              <span className="text-xs text-slate-400 uppercase tracking-wider">{t('finance.expenses')}</span>
            </div>
            <p className="text-2xl font-bold text-blue-400 font-display">₹{(financials.summary.totalExpenses / 100000).toFixed(1)}L</p>
          </div>
        </div>
        <div className="stat-card relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-cyan-500/10 to-transparent" />
          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              <DollarSign size={18} className="text-cyan-400" />
              <span className="text-xs text-slate-400 uppercase tracking-wider">{t('finance.balance')}</span>
            </div>
            <p className="text-2xl font-bold text-cyan-400 font-display">₹{(financials.summary.balance / 100000).toFixed(1)}L</p>
          </div>
        </div>
        <div className="stat-card relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-purple-500/10 to-transparent" />
          <div className="relative">
            <div className="flex items-center gap-2 mb-3">
              <PieChart size={18} className="text-purple-400" />
              <span className="text-xs text-slate-400 uppercase tracking-wider">{t('finance.corpus')}</span>
            </div>
            <p className="text-2xl font-bold text-purple-400 font-display">₹{(financials.summary.corpusFund / 100000).toFixed(1)}L</p>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="glass-card mb-6 overflow-hidden">
        <div className="flex border-b border-purple-500/20">
          {['overview', 'income', 'expenses', 'pending'].map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`flex-1 py-4 text-sm font-semibold capitalize transition-all ${
                activeTab === tab
                  ? 'text-cyan-400 bg-cyan-500/10 border-b-2 border-cyan-400'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
              }`}
            >
              {getTabLabel(tab)}
            </button>
          ))}
        </div>

        <div className="p-6">
          {activeTab === 'overview' && (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              {/* Income Breakdown */}
              <div>
                <h3 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
                  <TrendingUp size={18} className="text-emerald-400" />
                  {t('finance.incomeBreakdown', 'Income Breakdown')}
                </h3>
                <div className="space-y-4">
                  {financials.income.map((item) => {
                    const percentage = Math.round((item.amount / financials.summary.totalCollection) * 100)
                    return (
                      <div key={item.id}>
                        <div className="flex justify-between text-sm mb-2">
                          <span className="text-slate-400">{item.category}</span>
                          <span className="font-medium text-emerald-400">₹{(item.amount / 1000).toFixed(0)}K</span>
                        </div>
                        <div className="progress-cyber">
                          <div className="progress-cyber-fill" style={{ width: `${percentage}%` }} />
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>

              {/* Expense Breakdown */}
              <div>
                <h3 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
                  <TrendingDown size={18} className="text-blue-400" />
                  {t('finance.expenseBreakdown', 'Expense Breakdown')}
                </h3>
                <div className="space-y-4">
                  {financials.expenses.slice(0, 5).map((item) => {
                    const percentage = Math.round((item.amount / financials.summary.totalExpenses) * 100)
                    return (
                      <div key={item.id}>
                        <div className="flex justify-between text-sm mb-2">
                          <span className="text-slate-400">{item.category}</span>
                          <span className="font-medium text-blue-400">₹{(item.amount / 1000).toFixed(0)}K</span>
                        </div>
                        <div className="progress-cyber">
                          <div className="h-full rounded-full bg-gradient-to-r from-blue-500 to-cyan-500" style={{ width: `${percentage}%` }} />
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            </div>
          )}

          {activeTab === 'income' && (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-left text-sm text-slate-500 border-b border-purple-500/20">
                    <th className="pb-4 font-medium uppercase tracking-wider">{t('finance.category', 'Category')}</th>
                    <th className="pb-4 font-medium uppercase tracking-wider">{t('finance.month', 'Month')}</th>
                    <th className="pb-4 font-medium text-right uppercase tracking-wider">{t('finance.amount')}</th>
                  </tr>
                </thead>
                <tbody>
                  {financials.income.map((item) => (
                    <tr key={item.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                      <td className="py-4 font-medium text-white">{item.category}</td>
                      <td className="py-4 text-slate-400">{item.month}</td>
                      <td className="py-4 text-right font-bold text-emerald-400">₹{item.amount.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="bg-emerald-500/10">
                    <td colSpan={2} className="py-4 font-semibold text-white">{t('finance.totalIncome', 'Total Income')}</td>
                    <td className="py-4 text-right font-bold text-emerald-400 text-lg">₹{financials.summary.totalCollection.toLocaleString()}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          )}

          {activeTab === 'expenses' && (
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="text-left text-sm text-slate-500 border-b border-purple-500/20">
                    <th className="pb-4 font-medium uppercase tracking-wider">{t('finance.category', 'Category')}</th>
                    <th className="pb-4 font-medium uppercase tracking-wider">{t('finance.month', 'Month')}</th>
                    <th className="pb-4 font-medium text-right uppercase tracking-wider">{t('finance.amount')}</th>
                  </tr>
                </thead>
                <tbody>
                  {financials.expenses.map((item) => (
                    <tr key={item.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                      <td className="py-4 font-medium text-white">{item.category}</td>
                      <td className="py-4 text-slate-400">{item.month}</td>
                      <td className="py-4 text-right font-bold text-red-400">₹{item.amount.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr className="bg-red-500/10">
                    <td colSpan={2} className="py-4 font-semibold text-white">{t('finance.totalExpenses', 'Total Expenses')}</td>
                    <td className="py-4 text-right font-bold text-red-400 text-lg">₹{financials.summary.totalExpenses.toLocaleString()}</td>
                  </tr>
                </tfoot>
              </table>
            </div>
          )}

          {activeTab === 'pending' && (
            <div>
              <div className="rounded-xl bg-gradient-to-r from-red-500/10 to-orange-500/10 border border-red-500/20 p-5 mb-6">
                <div className="flex items-center gap-3 text-red-400">
                  <AlertCircle size={24} className="animate-pulse" />
                  <span className="text-lg font-bold font-display">{t('finance.totalPending', 'Total Pending')}: ₹{financials.summary.pendingDues.toLocaleString()}</span>
                </div>
              </div>
              <div className="space-y-4">
                {financials.pendingMembers.map((member, index) => (
                  <div key={index} className="flex items-center justify-between p-5 rounded-xl bg-slate-800/50 border border-slate-700/50 hover:border-red-500/30 transition-colors">
                    <div>
                      <p className="font-semibold text-white">{member.name}</p>
                      <p className="text-sm text-slate-500">{t('flats.flatNumber', 'Flat')} {member.flat} • {member.months} {t('finance.monthsPending', 'month(s) pending')}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xl font-bold text-red-400 font-display">₹{member.amount.toLocaleString()}</p>
                      <button className="text-sm text-purple-400 hover:text-purple-300 mt-1">{t('finance.sendReminder', 'Send Reminder')}</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
