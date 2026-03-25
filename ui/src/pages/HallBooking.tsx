import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CalendarDays, Plus, Clock, Users, DollarSign, CheckCircle, Clock4, Sparkles } from 'lucide-react'
import { hallBookings } from '../data/mockData'

const statusConfig = {
  'Confirmed': { color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30' },
  'Pending': { color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' },
  'Cancelled': { color: 'bg-red-500/20 text-red-400 border-red-500/30' },
}

export default function HallBooking() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)

  const confirmedBookings = hallBookings.filter(b => b.status === 'Confirmed').length
  const pendingBookings = hallBookings.filter(b => b.status === 'Pending').length
  const totalRevenue = hallBookings.filter(b => b.status === 'Confirmed').reduce((sum, b) => sum + b.amount, 0)

  const getStatusText = (status: string) => {
    switch (status) {
      case 'Confirmed': return t('hallBooking.confirmed')
      case 'Pending': return t('hallBooking.pending')
      case 'Cancelled': return t('hallBooking.cancelled')
      default: return status
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <Sparkles className="w-6 h-6 text-purple-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('hallBooking.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('hallBooking.description', 'Manage society hall reservations')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('hallBooking.newBooking', 'New Booking')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 border border-purple-500/30">
              <CalendarDays size={24} className="text-purple-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{hallBookings.length}</p>
              <p className="text-sm text-slate-400">{t('hallBooking.totalBookings', 'Total Bookings')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/30">
              <CheckCircle size={24} className="text-emerald-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-emerald-400 font-display">{confirmedBookings}</p>
              <p className="text-sm text-slate-400">{t('hallBooking.confirmed')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-yellow-500/20 border border-yellow-500/30">
              <Clock4 size={24} className="text-yellow-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-yellow-400 font-display">{pendingBookings}</p>
              <p className="text-sm text-slate-400">{t('hallBooking.pending')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-cyan-500/20 border border-cyan-500/30">
              <DollarSign size={24} className="text-cyan-400" />
            </div>
            <div>
              <p className="text-2xl font-bold text-cyan-400 font-display">₹{totalRevenue.toLocaleString()}</p>
              <p className="text-sm text-slate-400">{t('hallBooking.revenue', 'Revenue')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Bookings */}
      <div className="glass-card">
        <div className="p-6 border-b border-purple-500/20">
          <h2 className="text-lg font-semibold text-white flex items-center gap-2">
            <CalendarDays className="text-cyan-400" size={20} />
            {t('hallBooking.upcomingBookings', 'Upcoming Bookings')}
          </h2>
        </div>
        <div className="divide-y divide-slate-800/50">
          {hallBookings.map((booking) => (
            <div key={booking.id} className="p-6 hover:bg-slate-800/30 transition-colors">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-3">
                    <h3 className="font-semibold text-white text-lg">{booking.purpose}</h3>
                    <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${statusConfig[booking.status as keyof typeof statusConfig]?.color}`}>
                      {getStatusText(booking.status)}
                    </span>
                  </div>
                  <div className="flex flex-wrap gap-5 text-sm text-slate-400">
                    <span className="flex items-center gap-2">
                      <CalendarDays size={14} className="text-purple-400" />
                      {booking.date}
                    </span>
                    <span className="flex items-center gap-2">
                      <Clock size={14} className="text-cyan-400" />
                      {booking.timeSlot}
                    </span>
                    <span className="flex items-center gap-2">
                      <Users size={14} className="text-emerald-400" />
                      {booking.guests} {t('hallBooking.guests', 'guests')}
                    </span>
                    <span className="text-slate-300">{t('flats.flatNumber', 'Flat')}: <span className="text-white">{booking.flat}</span></span>
                  </div>
                </div>

                <div className="flex items-center gap-5">
                  <div className="text-right">
                    <p className="font-bold text-white text-lg">₹{booking.amount.toLocaleString()}</p>
                    <p className="text-sm text-slate-500">{t('hallBooking.deposit', 'Deposit')}: ₹{booking.deposit.toLocaleString()}</p>
                  </div>
                  <div className="flex gap-2">
                    {booking.status === 'Pending' && (
                      <>
                        <button className="px-4 py-2 text-sm font-medium text-emerald-400 bg-emerald-500/10 border border-emerald-500/30 rounded-xl hover:bg-emerald-500/20 transition-all">
                          {t('hallBooking.approve', 'Approve')}
                        </button>
                        <button className="px-4 py-2 text-sm font-medium text-red-400 bg-red-500/10 border border-red-500/30 rounded-xl hover:bg-red-500/20 transition-all">
                          {t('hallBooking.reject', 'Reject')}
                        </button>
                      </>
                    )}
                    {booking.status === 'Confirmed' && (
                      <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                        {t('common.view')} {t('hallBooking.details', 'Details')}
                      </button>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="glass-card w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="p-6 border-b border-purple-500/20">
              <h2 className="text-xl font-semibold text-white font-display">{t('hallBooking.bookHall')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('flats.flatNumber')}</label>
                <input type="text" className="input-cyber" placeholder="A-101" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('hallBooking.purpose')}</label>
                <input type="text" className="input-cyber" placeholder={t('hallBooking.purposePlaceholder', 'Birthday Party, Family Function, etc.')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('hallBooking.date')}</label>
                  <input type="date" className="input-cyber" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('hallBooking.expectedGuests', 'Expected Guests')}</label>
                  <input type="number" className="input-cyber" placeholder="50" />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('hallBooking.timeSlot')}</label>
                <select className="input-cyber">
                  <option>{t('hallBooking.morning', 'Morning')} (9:00 AM - 1:00 PM)</option>
                  <option>{t('hallBooking.afternoon', 'Afternoon')} (2:00 PM - 6:00 PM)</option>
                  <option>{t('hallBooking.evening', 'Evening')} (6:00 PM - 11:00 PM)</option>
                  <option>{t('hallBooking.fullDay', 'Full Day')} (9:00 AM - 11:00 PM)</option>
                </select>
              </div>
              <div className="rounded-xl bg-gradient-to-r from-purple-500/10 to-cyan-500/10 border border-purple-500/20 p-5">
                <h4 className="font-semibold text-white mb-3">{t('hallBooking.bookingCharges', 'Booking Charges')}</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-slate-400">{t('hallBooking.hallRent', 'Hall Rent')}</span>
                    <span className="font-medium text-white">₹5,000</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-400">{t('hallBooking.securityDeposit', 'Security Deposit')}</span>
                    <span className="font-medium text-white">₹2,000</span>
                  </div>
                  <div className="flex justify-between border-t border-purple-500/20 pt-2 mt-2">
                    <span className="text-white font-medium">{t('hallBooking.total', 'Total')}</span>
                    <span className="font-bold text-cyan-400">₹7,000</span>
                  </div>
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('hallBooking.submitRequest', 'Submit Request')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
