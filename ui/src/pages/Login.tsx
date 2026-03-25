import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Eye, EyeOff, Fingerprint, Shield, AlertCircle, Loader2 } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { ApiError } from '../api/client'
import LanguageSelector from '../components/LanguageSelector'

export default function Login() {
  const { t } = useTranslation()
  const { login } = useAuth()
  const [loginType, setLoginType] = useState<'member' | 'admin'>('member')
  const [showPassword, setShowPassword] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [formData, setFormData] = useState({ email: '', password: '' })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    try {
      await login(formData)
    } catch (err) {
      if (err instanceof ApiError) {
        switch (err.code) {
          case 'INVALID_CREDENTIALS':
            setError(t('login.errors.invalidCredentials'))
            break
          case 'ACCOUNT_LOCKED':
            setError(t('login.errors.accountLocked'))
            break
          case 'ACCOUNT_INACTIVE':
            setError(t('login.errors.accountInactive'))
            break
          default:
            setError(err.message || t('login.errors.serverError'))
        }
      } else {
        setError(t('login.errors.connectionError'))
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center p-4 relative overflow-hidden">
      {/* Language Selector */}
      <div className="absolute top-4 right-4 z-20">
        <LanguageSelector />
      </div>

      {/* Animated background elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-purple-500/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl animate-pulse delay-1000" />
        <div className="absolute top-1/2 left-1/2 w-64 h-64 bg-pink-500/10 rounded-full blur-3xl animate-pulse delay-500" />
      </div>

      <div className="w-full max-w-md relative z-10">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-24 h-24 rounded-full bg-white/10 backdrop-blur-sm mb-6 overflow-hidden border-2 border-purple-500/30 shadow-lg shadow-purple-500/20">
            <img src="/sai.jpg" alt="Sainath Logo" className="w-full h-full object-cover" />
          </div>
          <h1 className="font-display text-4xl font-bold gradient-text mb-2">{t('app.name')}</h1>
          <p className="text-slate-400 tracking-widest uppercase text-sm">{t('app.tagline')}</p>
        </div>

        {/* Login Card */}
        <div className="glass-card p-8">
          {/* Login Type Toggle */}
          <div className="flex mb-8 p-1.5 bg-slate-800/50 rounded-xl border border-purple-500/20">
            <button
              type="button"
              onClick={() => { setLoginType('member'); setError(null); }}
              className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-semibold rounded-lg transition-all duration-300 ${
                loginType === 'member'
                  ? 'bg-gradient-to-r from-purple-500 to-cyan-500 text-white shadow-lg'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Fingerprint size={18} />
              {t('login.member')}
            </button>
            <button
              type="button"
              onClick={() => { setLoginType('admin'); setError(null); }}
              className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-semibold rounded-lg transition-all duration-300 ${
                loginType === 'admin'
                  ? 'bg-gradient-to-r from-purple-500 to-cyan-500 text-white shadow-lg'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Shield size={18} />
              {t('login.admin')}
            </button>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-red-400">{error}</p>
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="mb-5">
              <label className="block text-sm font-medium text-slate-300 mb-2 tracking-wide">
                {loginType === 'admin' ? t('login.adminEmail') : t('login.email')}
              </label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                className="input-cyber"
                placeholder={loginType === 'admin' ? 'chairman@sainath.com' : 'member1@sainath.com'}
                required
                disabled={isLoading}
              />
            </div>

            <div className="mb-8">
              <label className="block text-sm font-medium text-slate-300 mb-2 tracking-wide">{t('login.password')}</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  className="input-cyber pr-12"
                  placeholder={t('login.enterPassword')}
                  required
                  disabled={isLoading}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-purple-400 transition-colors"
                  disabled={isLoading}
                >
                  {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              className="cyber-button w-full disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={isLoading}
            >
              <span className="flex items-center justify-center gap-2">
                {isLoading ? (
                  <>
                    <Loader2 size={18} className="animate-spin" />
                    {t('login.authenticating')}
                  </>
                ) : (
                  <>
                    <Shield size={18} />
                    {t('login.loginButton')}
                  </>
                )}
              </span>
            </button>

            <div className="mt-6 text-center">
              <button
                type="button"
                className="text-sm text-purple-400 hover:text-purple-300 transition-colors"
              >
                {t('login.forgotPassword')}
              </button>
            </div>
          </form>

          <div className="mt-8 pt-6 border-t border-purple-500/20 text-center">
            <p className="text-sm text-slate-500 mb-4">
              {t('login.newMember')}{' '}
              <Link to="/register" className="text-purple-400 hover:text-purple-300 font-medium">
                {t('login.registerHere')}
              </Link>
            </p>
            <p className="text-xs text-slate-600 mb-3">
              <span className="text-cyan-400">{t('login.demo')}</span> — {t('login.demoCredentials')}
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="mt-8 text-center">
          <p className="text-xs text-slate-600">
            {t('app.footer')}
          </p>
        </div>
      </div>
    </div>
  )
}
