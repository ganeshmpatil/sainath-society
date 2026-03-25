import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CheckSquare, Clock, AlertCircle, Plus, Calendar, User, ListTodo } from 'lucide-react'
import { pendingTasks } from '../data/mockData'

const statusColors = {
  'Pending': 'bg-red-500/20 text-red-400 border-red-500/30',
  'In Progress': 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  'Scheduled': 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  'Completed': 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
}

const priorityColors = {
  'High': 'bg-red-500 animate-pulse',
  'Medium': 'bg-yellow-500',
  'Low': 'bg-emerald-500',
}

const categoryColors = {
  'Compliance': 'bg-purple-500/20 text-purple-400 border-purple-500/30',
  'Safety': 'bg-red-500/20 text-red-400 border-red-500/30',
  'Maintenance': 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  'Administrative': 'bg-slate-500/20 text-slate-400 border-slate-500/30',
}

export default function PendingTasks() {
  const { t } = useTranslation()
  const [showModal, setShowModal] = useState(false)
  const [filterStatus, setFilterStatus] = useState('All')
  const [filterPriority, setFilterPriority] = useState('All')

  const filteredTasks = pendingTasks.filter(task => {
    const matchesStatus = filterStatus === 'All' || task.status === filterStatus
    const matchesPriority = filterPriority === 'All' || task.priority === filterPriority
    return matchesStatus && matchesPriority
  })

  const highPriorityCount = pendingTasks.filter(t => t.priority === 'High').length
  const pendingCount = pendingTasks.filter(t => t.status === 'Pending').length
  const inProgressCount = pendingTasks.filter(t => t.status === 'In Progress').length

  const getStatusText = (status: string) => {
    switch (status) {
      case 'Pending': return t('tasks.pending', 'Pending')
      case 'In Progress': return t('tasks.inProgress')
      case 'Scheduled': return t('tasks.scheduled', 'Scheduled')
      case 'Completed': return t('tasks.completed')
      default: return status
    }
  }

  const getPriorityText = (priority: string) => {
    switch (priority) {
      case 'High': return t('grievances.high')
      case 'Medium': return t('grievances.medium')
      case 'Low': return t('grievances.low')
      default: return priority
    }
  }

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-8">
        <div>
          <div className="flex items-center gap-3 mb-2">
            <ListTodo className="w-6 h-6 text-orange-400" />
            <h1 className="font-display text-3xl font-bold gradient-text">{t('tasks.title').toUpperCase()}</h1>
          </div>
          <p className="text-slate-400">{t('tasks.description', 'Society compliance and maintenance tasks')}</p>
        </div>
        <button onClick={() => setShowModal(true)} className="cyber-button mt-4 sm:mt-0">
          <span className="flex items-center gap-2">
            <Plus size={18} />
            {t('tasks.addTask', 'Add Task')}
          </span>
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 border border-purple-500/30">
              <CheckSquare size={24} className="text-purple-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-white font-display">{pendingTasks.length}</p>
              <p className="text-sm text-slate-400">{t('tasks.total', 'Total')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-red-500/20 border border-red-500/30">
              <AlertCircle size={24} className="text-red-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-red-400 font-display">{highPriorityCount}</p>
              <p className="text-sm text-slate-400">{t('tasks.highPriority', 'High Priority')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-yellow-500/20 border border-yellow-500/30">
              <Clock size={24} className="text-yellow-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-yellow-400 font-display">{inProgressCount}</p>
              <p className="text-sm text-slate-400">{t('tasks.inProgress')}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-xl bg-orange-500/20 border border-orange-500/30">
              <Calendar size={24} className="text-orange-400" />
            </div>
            <div>
              <p className="text-3xl font-bold text-orange-400 font-display">{pendingCount}</p>
              <p className="text-sm text-slate-400">{t('tasks.pending', 'Pending')}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Filters */}
      <div className="glass-card p-5 mb-6">
        <div className="flex flex-col sm:flex-row gap-4">
          <select
            value={filterStatus}
            onChange={(e) => setFilterStatus(e.target.value)}
            className="input-cyber"
          >
            <option value="All">{t('grievances.allStatus')}</option>
            <option value="Pending">{t('tasks.pending', 'Pending')}</option>
            <option value="In Progress">{t('tasks.inProgress')}</option>
            <option value="Scheduled">{t('tasks.scheduled', 'Scheduled')}</option>
          </select>
          <select
            value={filterPriority}
            onChange={(e) => setFilterPriority(e.target.value)}
            className="input-cyber"
          >
            <option value="All">{t('tasks.allPriority', 'All Priority')}</option>
            <option value="High">{t('grievances.high')}</option>
            <option value="Medium">{t('grievances.medium')}</option>
            <option value="Low">{t('grievances.low')}</option>
          </select>
        </div>
      </div>

      {/* Task List */}
      <div className="space-y-4">
        {filteredTasks.map((task) => (
          <div key={task.id} className="glass-card-hover p-6">
            <div className="flex items-start gap-4">
              <div className={`w-3 h-3 rounded-full mt-2 ${priorityColors[task.priority as keyof typeof priorityColors]}`} />
              <div className="flex-1">
                <div className="flex flex-wrap items-center gap-3 mb-3">
                  <h3 className="font-semibold text-white text-lg">{task.title}</h3>
                  <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${statusColors[task.status as keyof typeof statusColors]}`}>
                    {getStatusText(task.status)}
                  </span>
                  <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${categoryColors[task.category as keyof typeof categoryColors]}`}>
                    {task.category}
                  </span>
                </div>

                <div className="flex flex-wrap items-center gap-6 text-sm text-slate-400">
                  <span className="flex items-center gap-2">
                    <Calendar size={14} className="text-orange-400" />
                    {t('tasks.due', 'Due')}: <span className="text-white">{task.dueDate}</span>
                  </span>
                  <span className="flex items-center gap-2">
                    <User size={14} className="text-cyan-400" />
                    {task.assignedTo}
                  </span>
                  <span className={`px-3 py-1 text-xs font-semibold rounded-lg border ${
                    task.priority === 'High' ? 'bg-red-500/20 text-red-400 border-red-500/30' :
                    task.priority === 'Medium' ? 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30' : 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                  }`}>
                    {getPriorityText(task.priority)} {t('tasks.priority')}
                  </span>
                </div>
              </div>

              <div className="flex gap-2">
                <button className="px-4 py-2 text-sm font-medium text-purple-400 bg-purple-500/10 border border-purple-500/30 rounded-xl hover:bg-purple-500/20 transition-all">
                  {t('tasks.update', 'Update')}
                </button>
                <button className="px-4 py-2 text-sm font-medium text-emerald-400 bg-emerald-500/10 border border-emerald-500/30 rounded-xl hover:bg-emerald-500/20 transition-all">
                  {t('tasks.complete', 'Complete')}
                </button>
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
              <h2 className="text-xl font-semibold text-white font-display">{t('tasks.addNewTask', 'Add New Task')}</h2>
            </div>
            <div className="p-6 space-y-5">
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">{t('tasks.taskTitle', 'Task Title')}</label>
                <input type="text" className="input-cyber" placeholder={t('tasks.taskTitlePlaceholder', 'Enter task title')} />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('tasks.category', 'Category')}</label>
                  <select className="input-cyber">
                    <option>{t('tasks.compliance', 'Compliance')}</option>
                    <option>{t('tasks.safety', 'Safety')}</option>
                    <option>{t('tasks.maintenance', 'Maintenance')}</option>
                    <option>{t('tasks.administrative', 'Administrative')}</option>
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('tasks.priority')}</label>
                  <select className="input-cyber">
                    <option>{t('grievances.high')}</option>
                    <option>{t('grievances.medium')}</option>
                    <option>{t('grievances.low')}</option>
                  </select>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('tasks.dueDate')}</label>
                  <input type="date" className="input-cyber" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-2">{t('tasks.assignedTo')}</label>
                  <select className="input-cyber">
                    <option>{t('tasks.secretary', 'Secretary')}</option>
                    <option>{t('tasks.treasurer', 'Treasurer')}</option>
                    <option>{t('tasks.maintenanceHead', 'Maintenance Head')}</option>
                    <option>{t('tasks.chairman', 'Chairman')}</option>
                  </select>
                </div>
              </div>
            </div>
            <div className="p-6 border-t border-purple-500/20 flex justify-end gap-3">
              <button onClick={() => setShowModal(false)} className="px-5 py-2.5 text-slate-400 hover:bg-slate-800 rounded-xl transition-colors">
                {t('common.cancel')}
              </button>
              <button onClick={() => setShowModal(false)} className="cyber-button">
                <span>{t('tasks.addTask', 'Add Task')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
