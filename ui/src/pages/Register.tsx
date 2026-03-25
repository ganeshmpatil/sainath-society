import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Phone, Shield, Key, Mail, Eye, EyeOff,
  AlertCircle, Loader2, CheckCircle, ArrowLeft, RefreshCw
} from 'lucide-react'
import { registrationApi, MemberInfo } from '../api/registration'
import { ApiError } from '../api/client'
import LanguageSelector from '../components/LanguageSelector'

type Step = 'mobile' | 'otp' | 'credentials' | 'success'

export default function Register() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [step, setStep] = useState<Step>('mobile')
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [showPassword, setShowPassword] = useState(false)

  // Form data
  const [mobile, setMobile] = useState('')
  const [otp, setOtp] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')

  // Member info from server
  const [memberInfo, setMemberInfo] = useState<MemberInfo | null>(null)
  const [otpExpiry, setOtpExpiry] = useState(300)

  // Step 1: Initiate registration with mobile
  const handleInitiate = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    try {
      const response = await registrationApi.initiate(mobile)
      setMemberInfo(response.member)
      setOtpExpiry(response.otpExpiry)
      setStep('otp')
    } catch (err) {
      if (err instanceof ApiError) {
        switch (err.code) {
          case 'MEMBER_NOT_FOUND':
            setError(t('register.errors.memberNotFound'))
            break
          case 'ALREADY_REGISTERED':
            setError(t('register.errors.alreadyRegistered'))
            break
          case 'MEMBER_INACTIVE':
            setError(t('register.errors.memberInactive'))
            break
          default:
            setError(err.message || t('register.errors.initiateFailed'))
        }
      } else {
        setError(t('register.errors.connectionError'))
      }
    } finally {
      setIsLoading(false)
    }
  }

  // Step 2: Verify OTP
  const handleVerifyOTP = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    setIsLoading(true)

    try {
      await registrationApi.verifyOTP(mobile, otp)
      setStep('credentials')
    } catch (err) {
      if (err instanceof ApiError) {
        switch (err.code) {
          case 'INVALID_OTP':
            setError(t('register.errors.invalidOtp'))
            break
          case 'OTP_EXPIRED':
            setError(t('register.errors.otpExpired'))
            break
          case 'OTP_MAX_ATTEMPTS':
            setError(t('register.errors.otpMaxAttempts'))
            break
          default:
            setError(err.message || t('register.errors.verifyFailed'))
        }
      } else {
        setError(t('register.errors.connectionError'))
      }
    } finally {
      setIsLoading(false)
    }
  }

  // Step 3: Complete registration
  const handleComplete = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)

    if (password !== confirmPassword) {
      setError(t('register.errors.passwordMismatch'))
      return
    }

    if (password.length < 8) {
      setError(t('register.errors.passwordLength'))
      return
    }

    setIsLoading(true)

    try {
      await registrationApi.complete(mobile, email, password)
      setStep('success')
    } catch (err) {
      if (err instanceof ApiError) {
        switch (err.code) {
          case 'EMAIL_EXISTS':
            setError(t('register.errors.emailExists'))
            break
          case 'ALREADY_REGISTERED':
            setError(t('register.errors.alreadyRegistered'))
            break
          default:
            setError(err.message || t('register.errors.completeFailed'))
        }
      } else {
        setError(t('register.errors.connectionError'))
      }
    } finally {
      setIsLoading(false)
    }
  }

  // Resend OTP
  const handleResendOTP = async () => {
    setError(null)
    setIsLoading(true)

    try {
      await registrationApi.resendOTP(mobile)
      setOtp('')
      setError(null)
    } catch (err) {
      setError(t('register.errors.resendFailed'))
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

      {/* Background */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-purple-500/20 rounded-full blur-3xl animate-pulse" />
        <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl animate-pulse delay-1000" />
      </div>

      <div className="w-full max-w-md relative z-10">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-24 h-24 rounded-full bg-white/10 backdrop-blur-sm mb-6 overflow-hidden border-2 border-purple-500/30 shadow-lg shadow-purple-500/20">
            <img src="/sai.jpg" alt="Sainath Logo" className="w-full h-full object-cover" />
          </div>
          <h1 className="font-display text-4xl font-bold gradient-text mb-2">{t('app.name')}</h1>
          <p className="text-slate-400 tracking-widest uppercase text-sm">{t('register.title')}</p>
        </div>

        {/* Registration Card */}
        <div className="glass-card p-8">
          {/* Progress Steps */}
          <div className="flex items-center justify-center gap-2 mb-8">
            {['mobile', 'otp', 'credentials'].map((s, i) => (
              <div key={s} className="flex items-center">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                  step === s ? 'bg-gradient-to-r from-purple-500 to-cyan-500 text-white' :
                  ['mobile', 'otp', 'credentials'].indexOf(step) > i ? 'bg-green-500 text-white' :
                  'bg-slate-700 text-slate-400'
                }`}>
                  {['mobile', 'otp', 'credentials'].indexOf(step) > i ? <CheckCircle size={16} /> : i + 1}
                </div>
                {i < 2 && <div className={`w-8 h-0.5 ${
                  ['mobile', 'otp', 'credentials'].indexOf(step) > i ? 'bg-green-500' : 'bg-slate-700'
                }`} />}
              </div>
            ))}
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/30 flex items-start gap-3">
              <AlertCircle className="w-5 h-5 text-red-400 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-red-400">{error}</p>
            </div>
          )}

          {/* Step 1: Mobile Number */}
          {step === 'mobile' && (
            <form onSubmit={handleInitiate}>
              <div className="mb-6">
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  {t('register.mobile.label')}
                </label>
                <div className="relative">
                  <Phone className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
                  <input
                    type="tel"
                    value={mobile}
                    onChange={(e) => setMobile(e.target.value.replace(/\D/g, '').slice(0, 10))}
                    className="input-cyber pl-11"
                    placeholder={t('register.mobile.placeholder')}
                    required
                    disabled={isLoading}
                  />
                </div>
                <p className="text-xs text-slate-500 mt-2">
                  {t('register.mobile.hint')}
                </p>
              </div>

              <button
                type="submit"
                className="cyber-button w-full"
                disabled={isLoading || mobile.length < 10}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Loader2 size={18} className="animate-spin" />
                    {t('register.mobile.verifying')}
                  </span>
                ) : (
                  <span className="flex items-center justify-center gap-2">
                    <Shield size={18} />
                    {t('register.mobile.sendOtp')}
                  </span>
                )}
              </button>
            </form>
          )}

          {/* Step 2: OTP Verification */}
          {step === 'otp' && (
            <form onSubmit={handleVerifyOTP}>
              {memberInfo && (
                <div className="mb-6 p-4 rounded-xl bg-slate-800/50 border border-purple-500/20">
                  <p className="text-sm text-slate-400 mb-1">{t('register.otp.registeringAs')}</p>
                  <p className="text-lg font-semibold text-white">{memberInfo.name}</p>
                  <p className="text-sm text-purple-400">
                    {memberInfo.flatNumber} • {memberInfo.role}
                  </p>
                </div>
              )}

              <div className="mb-6">
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  {t('register.otp.label')}
                </label>
                <div className="relative">
                  <Key className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
                  <input
                    type="text"
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    className="input-cyber pl-11 text-center tracking-widest text-xl"
                    placeholder={t('register.otp.placeholder')}
                    maxLength={6}
                    required
                    disabled={isLoading}
                  />
                </div>
                <p className="text-xs text-slate-500 mt-2">
                  {t('register.otp.sentTo')} {memberInfo?.mobile}
                </p>
              </div>

              <button
                type="submit"
                className="cyber-button w-full mb-4"
                disabled={isLoading || otp.length < 6}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Loader2 size={18} className="animate-spin" />
                    {t('register.otp.verifying')}
                  </span>
                ) : (
                  <span className="flex items-center justify-center gap-2">
                    <CheckCircle size={18} />
                    {t('register.otp.verify')}
                  </span>
                )}
              </button>

              <div className="flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => setStep('mobile')}
                  className="text-sm text-slate-400 hover:text-white flex items-center gap-1"
                >
                  <ArrowLeft size={14} />
                  {t('register.otp.changeNumber')}
                </button>
                <button
                  type="button"
                  onClick={handleResendOTP}
                  disabled={isLoading}
                  className="text-sm text-purple-400 hover:text-purple-300 flex items-center gap-1"
                >
                  <RefreshCw size={14} />
                  {t('register.otp.resend')}
                </button>
              </div>
            </form>
          )}

          {/* Step 3: Create Credentials */}
          {step === 'credentials' && (
            <form onSubmit={handleComplete}>
              {memberInfo && (
                <div className="mb-6 p-4 rounded-xl bg-slate-800/50 border border-green-500/20">
                  <div className="flex items-center gap-2 mb-2">
                    <CheckCircle className="w-4 h-4 text-green-400" />
                    <p className="text-sm text-green-400">{t('register.credentials.mobileVerified')}</p>
                  </div>
                  <p className="text-lg font-semibold text-white">{memberInfo.name}</p>
                </div>
              )}

              <div className="mb-5">
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  {t('register.credentials.email')}
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="input-cyber pl-11"
                    placeholder={t('register.credentials.emailPlaceholder')}
                    required
                    disabled={isLoading}
                  />
                </div>
              </div>

              <div className="mb-5">
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  {t('register.credentials.password')}
                </label>
                <div className="relative">
                  <Key className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="input-cyber pl-11 pr-11"
                    placeholder={t('register.credentials.passwordPlaceholder')}
                    required
                    minLength={8}
                    disabled={isLoading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-purple-400"
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div className="mb-8">
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  {t('register.credentials.confirmPassword')}
                </label>
                <div className="relative">
                  <Key className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-500" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="input-cyber pl-11"
                    placeholder={t('register.credentials.confirmPlaceholder')}
                    required
                    disabled={isLoading}
                  />
                </div>
              </div>

              <button
                type="submit"
                className="cyber-button w-full"
                disabled={isLoading}
              >
                {isLoading ? (
                  <span className="flex items-center justify-center gap-2">
                    <Loader2 size={18} className="animate-spin" />
                    {t('register.credentials.creating')}
                  </span>
                ) : (
                  <span className="flex items-center justify-center gap-2">
                    <Shield size={18} />
                    {t('register.credentials.complete')}
                  </span>
                )}
              </button>
            </form>
          )}

          {/* Success */}
          {step === 'success' && (
            <div className="text-center">
              <div className="w-20 h-20 rounded-full bg-green-500/20 flex items-center justify-center mx-auto mb-6">
                <CheckCircle className="w-10 h-10 text-green-400" />
              </div>
              <h2 className="text-2xl font-bold text-white mb-2">{t('register.success.title')}</h2>
              <p className="text-slate-400 mb-8">
                {t('register.success.message')}
              </p>
              <button
                onClick={() => navigate('/login')}
                className="cyber-button w-full"
              >
                <span className="flex items-center justify-center gap-2">
                  <Shield size={18} />
                  {t('register.success.goToLogin')}
                </span>
              </button>
            </div>
          )}

          {/* Back to login link */}
          {step !== 'success' && (
            <div className="mt-8 pt-6 border-t border-purple-500/20 text-center">
              <p className="text-sm text-slate-500">
                {t('register.alreadyRegistered')}{' '}
                <Link to="/login" className="text-purple-400 hover:text-purple-300">
                  {t('register.loginHere')}
                </Link>
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
