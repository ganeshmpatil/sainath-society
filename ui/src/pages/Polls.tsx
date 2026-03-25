import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Vote, Plus, Clock, CheckCircle, Users, Zap, Trophy } from 'lucide-react'
import { polls } from '../data/mockData'

export default function Polls() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Vote className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('polls.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('polls.description', 'Society polls and member voting')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('polls.createPoll', 'Create Poll')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-8">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/30">
              <Zap size={24} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{polls.filter(p => p.status === 'Active').length}</p>
              <p className="text-sm text-slate-400">{t('polls.activePolls', 'Active Polls')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-slate-500/20 border border-slate-500/30">
              <CheckCircle size={24} className="text-slate-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{polls.filter(p => p.status === 'Closed').length}</p>
              <p className="text-sm text-slate-400">{t('polls.closedPolls', 'Closed Polls')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-cyan-500/20 border border-cyan-500/30">
              <Users size={24} className="text-cyan-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">72</p>
              <p className="text-sm text-slate-400">{t('polls.totalMembers', 'Total Members')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Active Polls */}
      <div className="mb-8">
        <h2 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
          <Zap className="text-emerald-400" size={20} />
          {t('polls.activePolls', 'Active Polls')}
        </h2>
        <div className="space-y-5">
          {polls.filter(p => p.status === 'Active').map((poll) => {
            const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0)
            const maxVotes = Math.max(...poll.options.map(opt => opt.votes))

            return (
              <div key={poll.id} className="glass-card p-6">
                <div className="flex items-start justify-between mb-5">
                  <div>
                    <h3 className="font-semibold text-white text-xl">{poll.title}</h3>
                    <div className="flex items-center gap-6 mt-2 text-sm text-slate-400">
                      <span className="flex items-center gap-2">
                        <Clock size={14} className="text-orange-400" />
                        {t('polls.ends', 'Ends')}: {poll.endDate}
                      </span>
                      <span className="flex items-center gap-2">
                        <Users size={14} className="text-cyan-400" />
                        {totalVotes}/{poll.totalVoters} {t('polls.voted', 'voted')}
                      </span>
                    </div>
                  </div>
                  <span className="px-3 py-1.5 text-xs font-semibold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-lg animate-pulse">
                    {t('polls.live', 'LIVE')}
                  </span>
                </div>

                <div className="space-y-3">
                  {poll.options.map((option, index) => {
                    const percentage = totalVotes > 0 ? Math.round((option.votes / totalVotes) * 100) : 0
                    const isLeading = option.votes === maxVotes && maxVotes > 0

                    return (
                      <div key={index} className="relative group">
                        <div className={`flex items-center justify-between p-4 rounded-xl border-2 transition-all cursor-pointer ${
                          isLeading
                            ? 'border-purple-500/50 bg-purple-500/10'
                            : 'border-slate-700/50 bg-slate-800/30 hover:border-purple-500/30'
                        }`}>
                          <div className="flex items-center gap-4">
                            <div className={`w-5 h-5 rounded-full border-2 ${
                              isLeading ? 'border-purple-400' : 'border-slate-500'
                            } flex items-center justify-center`}>
                              {isLeading && <div className="w-2.5 h-2.5 rounded-full bg-purple-400" />}
                            </div>
                            <span className="font-medium text-white">{option.text}</span>
                            {isLeading && <Trophy size={16} className="text-yellow-400" />}
                          </div>
                          <span className="text-sm text-slate-400">{option.votes} {t('polls.votes', 'votes')} ({percentage}%)</span>
                        </div>
                        <div className="absolute bottom-0 left-0 h-1 rounded-b-xl transition-all bg-gradient-to-r from-purple-500 to-cyan-500" style={{ width: `${percentage}%` }} />
                      </div>
                    )
                  })}
                </div>

                <div className="mt-6 pt-5 border-t border-slate-700/50 flex justify-end">
                  <button className="cyber-button">
                    <span>{t('polls.submitVote', 'Submit Vote')}</span>
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Closed Polls */}
      <div>
        <h2 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
          <CheckCircle className="text-slate-400" size={20} />
          {t('polls.closedPolls', 'Closed Polls')}
        </h2>
        <div className="space-y-4">
          {polls.filter(p => p.status === 'Closed').map((poll) => {
            const totalVotes = poll.options.reduce((sum, opt) => sum + opt.votes, 0)
            const winner = poll.options.reduce((max, opt) => opt.votes > max.votes ? opt : max, poll.options[0])

            return (
              <div key={poll.id} className="glass-card p-6 opacity-80">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="font-semibold text-white text-lg">{poll.title}</h3>
                    <p className="text-sm text-slate-500 mt-1">{t('polls.ended', 'Ended')}: {poll.endDate}</p>
                  </div>
                  <span className="px-3 py-1 text-xs font-medium bg-slate-700/50 text-slate-400 border border-slate-600/30 rounded-lg">
                    {t('polls.closed')}
                  </span>
                </div>

                <div className="rounded-xl bg-gradient-to-r from-emerald-500/10 to-cyan-500/10 border border-emerald-500/20 p-5">
                  <div className="flex items-center gap-2 text-sm text-emerald-400 mb-2">
                    <Trophy size={16} />
                    {t('polls.winner', 'Winner')}
                  </div>
                  <p className="text-xl font-bold text-white">{winner.text}</p>
                  <p className="text-sm text-emerald-400 mt-1">{winner.votes} {t('polls.votes', 'votes')} ({Math.round((winner.votes / totalVotes) * 100)}%)</p>
                </div>

                <button className="mt-4 text-sm text-purple-400 hover:text-purple-300">
                  {t('polls.viewFullResults', 'View Full Results')}
                </button>
              </div>
            )
          })}
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('polls.createNewPoll', 'Create New Poll')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('polls.pollQuestion', 'Poll Question')}</label>
                <input type="text" className="input-cyber" placeholder={t('polls.questionPlaceholder', 'What do you want to ask?')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('polls.options')}</label>
                <div className="space-y-3">
                  <input type="text" className="input-cyber" placeholder={`${t('polls.option', 'Option')} 1`} />
                  <input type="text" className="input-cyber" placeholder={`${t('polls.option', 'Option')} 2`} />
                  <input type="text" className="input-cyber" placeholder={`${t('polls.option', 'Option')} 3`} />
                </div>
                <button className="mt-3 text-sm text-purple-400 hover:text-purple-300">+ {t('polls.addOption', 'Add Option')}</button>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('polls.endDate')}</label>
                <input type="date" className="input-cyber" />
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('polls.createPoll', 'Create Poll')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
