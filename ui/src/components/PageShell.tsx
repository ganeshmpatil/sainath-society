import { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Loader2, AlertCircle, RefreshCw } from 'lucide-react'

interface PageShellProps {
  title: string
  subtitle?: string
  icon?: React.ElementType
  actions?: ReactNode
  loading?: boolean
  error?: string | null
  onRetry?: () => void
  children: ReactNode
}

/**
 * PageShell — consistent layout wrapper for every module page:
 * header + optional action buttons, loading state, error state with retry,
 * and the actual content area.
 */
export default function PageShell({
  title, subtitle, icon: Icon, actions,
  loading, error, onRetry, children
}: PageShellProps) {
  const { t } = useTranslation()

  return (
    <div>
      <div className="mb-6 flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="flex items-center gap-3 mb-1">
            {Icon && <Icon className="w-6 h-6 text-purple-400" />}
            <h1 className="font-display text-3xl font-bold gradient-text">{title}</h1>
          </div>
          {subtitle && <p className="text-slate-400 text-sm">{subtitle}</p>}
        </div>
        {actions && <div className="flex items-center gap-2">{actions}</div>}
      </div>

      {loading && (
        <div className="glass-card p-12 flex flex-col items-center justify-center">
          <Loader2 className="w-10 h-10 text-purple-400 animate-spin mb-3" />
          <p className="text-slate-400">{t('common.loading')}</p>
        </div>
      )}

      {error && !loading && (
        <div className="glass-card p-8 border border-red-500/30 bg-red-500/5">
          <div className="flex items-start gap-3">
            <AlertCircle className="w-6 h-6 text-red-400 flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <h3 className="font-semibold text-red-400 mb-1">{t('common.loadFailed')}</h3>
              <p className="text-sm text-slate-400">{error}</p>
            </div>
            {onRetry && (
              <button
                onClick={onRetry}
                className="flex items-center gap-2 px-4 py-2 rounded-lg bg-purple-500/20 text-purple-400 hover:bg-purple-500/30 transition-colors text-sm"
              >
                <RefreshCw size={14} /> {t('common.retry')}
              </button>
            )}
          </div>
        </div>
      )}

      {!loading && !error && children}
    </div>
  )
}
