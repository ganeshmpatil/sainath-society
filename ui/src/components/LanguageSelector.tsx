import { useTranslation } from 'react-i18next'
import { Globe } from 'lucide-react'

export default function LanguageSelector({ className = '' }: { className?: string }) {
  const { i18n } = useTranslation()

  const toggleLanguage = () => {
    const newLang = i18n.language === 'mr' ? 'en' : 'mr'
    i18n.changeLanguage(newLang)
  }

  return (
    <button
      onClick={toggleLanguage}
      className={`flex items-center gap-2 px-3 py-2 rounded-lg bg-slate-800/50 border border-purple-500/20 hover:border-purple-500/40 transition-all ${className}`}
      title={i18n.language === 'mr' ? 'Switch to English' : 'मराठी मध्ये बदला'}
    >
      <Globe size={16} className="text-purple-400" />
      <span className="text-sm font-medium text-slate-300">
        {i18n.language === 'mr' ? 'EN' : 'मराठी'}
      </span>
    </button>
  )
}
