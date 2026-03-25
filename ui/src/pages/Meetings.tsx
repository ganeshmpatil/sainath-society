import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Calendar, Clock, MapPin, Users, Plus, FileText, CheckCircle, Video } from 'lucide-react'
import { meetings } from '../data/mockData'

const typeColors = {
  'AGM': 'bg-purple-500/20 text-purple-400 border-purple-500/30',
  'SGM': 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  'Committee': 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
}

export default function Meetings() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)

  const scheduledMeetings = meetings.filter(m => m.status === 'Scheduled')
  const completedMeetings = meetings.filter(m => m.status === 'Completed')

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Video className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('meetings.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('meetings.description', 'Manage society meetings and agendas')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('meetings.newMeeting')}
          </span>
        </button>
      </div>

      {/* Upcoming Meetings */}
      <div className="mb-8">
        <h2 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
          <Calendar className="text-cyan-400" size={20} />
          {t('meetings.upcomingMeetings', 'Upcoming Meetings')}
        </h2>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
          {scheduledMeetings.map((meeting) => (
            <div key={meeting.id} className="glass-card-hover p-6 group">
              <div className="flex items-start justify-between mb-4">
                <span className={`px-3 py-1.5 text-xs font-semibold rounded-lg border ${typeColors[meeting.type as keyof typeof typeColors]}`}>
                  {meeting.type}
                </span>
                <span className="px-3 py-1.5 text-xs font-semibold bg-yellow-500/20 text-yellow-400 border border-yellow-500/30 rounded-lg animate-pulse">
                  {t('meetings.scheduled', 'Scheduled')}
                </span>
              </div>

              <h3 className="font-bold text-white text-xl mb-4">{meeting.title}</h3>

              <div className="space-y-3 text-sm">
                <div className="flex items-center gap-3 text-slate-400">
                  <Calendar size={16} className="text-purple-400" />
                  <span>{meeting.date}</span>
                </div>
                <div className="flex items-center gap-3 text-slate-400">
                  <Clock size={16} className="text-cyan-400" />
                  <span>{meeting.time}</span>
                </div>
                <div className="flex items-center gap-3 text-slate-400">
                  <MapPin size={16} className="text-pink-400" />
                  <span>{meeting.venue}</span>
                </div>
                <div className="flex items-center gap-3 text-slate-400">
                  <Users size={16} className="text-emerald-400" />
                  <span>{t('meetings.expected', 'Expected')}: <span className="text-white">{meeting.expectedAttendees}</span> | {t('meetings.quorum', 'Quorum')}: <span className="text-white">{meeting.quorum}</span></span>
                </div>
              </div>

              <div className="mt-5 pt-5 border-t border-slate-700/50">
                <p className="text-sm font-semibold text-slate-300 mb-3">{t('meetings.agendaItems', 'Agenda Items')}:</p>
                <ul className="space-y-2">
                  {meeting.agenda.slice(0, 3).map((item, index) => (
                    <li key={index} className="text-sm text-slate-400 flex items-center gap-2">
                      <span className="w-2 h-2 bg-gradient-to-r from-purple-500 to-cyan-500 rounded-full" />
                      {item}
                    </li>
                  ))}
                  {meeting.agenda.length > 3 && (
                    <li className="text-sm text-purple-400">+{meeting.agenda.length - 3} {t('meetings.moreItems', 'more items')}</li>
                  )}
                </ul>
              </div>

              <div className="mt-5 flex gap-3">
                <button className="flex-1 py-2.5 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                  {t('meetings.viewDetails', 'View Details')}
                </button>
                <button className="flex-1 py-2.5 text-sm font-medium text-emerald-400 bg-emerald-500/10 border border-emerald-500/30 rounded-xl hover:bg-emerald-500/20 transition-all">
                  {t('meetings.rsvp', 'RSVP')}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Completed Meetings */}
      <div>
        <h2 className="text-lg font-semibold text-white mb-5 flex items-center gap-2">
          <CheckCircle className="text-emerald-400" size={20} />
          {t('meetings.pastMeetings', 'Past Meetings')}
        </h2>
        <div className="glass-card overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-purple-500/20">
                <th className="px-6 py-4 text-left text-sm font-semibold text-slate-400 uppercase tracking-wider">{t('meetings.meeting', 'Meeting')}</th>
                <th className="px-6 py-4 text-left text-sm font-semibold text-slate-400 uppercase tracking-wider">{t('meetings.type', 'Type')}</th>
                <th className="px-6 py-4 text-left text-sm font-semibold text-slate-400 uppercase tracking-wider">{t('common.date')}</th>
                <th className="px-6 py-4 text-left text-sm font-semibold text-slate-400 uppercase tracking-wider">{t('common.status')}</th>
                <th className="px-6 py-4 text-left text-sm font-semibold text-slate-400 uppercase tracking-wider">{t('common.actions')}</th>
              </tr>
            </thead>
            <tbody>
              {completedMeetings.map((meeting) => (
                <tr key={meeting.id} className="border-b border-slate-800/50 hover:bg-slate-800/30">
                  <td className="px-6 py-4">
                    <p className="font-semibold text-white">{meeting.title}</p>
                    <p className="text-sm text-slate-500">{meeting.venue}</p>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${typeColors[meeting.type as keyof typeof typeColors]}`}>
                      {meeting.type}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-sm text-slate-400">{meeting.date}</td>
                  <td className="px-6 py-4">
                    <span className="flex items-center gap-2 text-sm text-emerald-400">
                      <CheckCircle size={14} />
                      {t('meetings.completed', 'Completed')}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <button className="text-sm text-purple-400 hover:text-purple-300 flex items-center gap-2">
                      <FileText size={14} />
                      {t('meetings.viewMinutes', 'View Minutes')}
                    </button>
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
          <div className="glass-card w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('meetings.newMeeting')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('meetings.meetingType', 'Meeting Type')}</label>
                <select className="input-cyber">
                  <option>{t('meetings.agm')} - {t('meetings.annualGeneralMeeting', 'Annual General Meeting')}</option>
                  <option>SGM - {t('meetings.specialGeneralMeeting', 'Special General Meeting')}</option>
                  <option>{t('meetings.committee')}</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('meetings.titleLabel', 'Title')}</label>
                <input type="text" className="input-cyber" placeholder={t('meetings.titlePlaceholder', 'Meeting title')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('common.date')}</label>
                  <input type="date" className="input-cyber" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('meetings.time', 'Time')}</label>
                  <input type="time" className="input-cyber" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('meetings.venue')}</label>
                <input type="text" className="input-cyber" placeholder={t('meetings.venuePlaceholder', 'Society Hall')} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('meetings.agendaItems', 'Agenda Items')}</label>
                <textarea rows={4} className="input-cyber" placeholder={t('meetings.agendaPlaceholder', 'Enter each agenda item on a new line')} />
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('meetings.schedule', 'Schedule')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
