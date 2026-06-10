import { ReactNode, useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

interface LayoutProps {
  children: ReactNode
}

const navigation = [
  {
    chemin: '/dialogue',
    label: 'Dialogue',
    icone: '💬',
    description: 'Interagir avec l\'Agent Pilote',
    roles: ['ROLE_CLINICIEN', 'ROLE_ADMIN', 'ROLE_QUALITICIEN', 'ROLE_RSSI'],
  },
  {
    chemin: '/supervision',
    label: 'Supervision',
    icone: '📊',
    description: 'Monitorer le système en temps réel',
    roles: ['ROLE_QUALITICIEN', 'ROLE_ADMIN', 'ROLE_RSSI'],
  },
  {
    chemin: '/administration',
    label: 'Administration',
    icone: '⚙️',
    description: 'Configurer et administrer HERMES',
    roles: ['ROLE_ADMIN', 'ROLE_RSSI', 'ROLE_ADMIN_PRIVACY'],
  },
]

export default function Layout({ children }: LayoutProps) {
  const { utilisateur, deconnexion } = useAuth()
  const navigate = useNavigate()
  const [menuOuvert, setMenuOuvert] = useState(false)

  const handleDeconnexion = () => {
    deconnexion()
    navigate('/')
  }

  const navAccessibles = navigation.filter(
    n => !utilisateur || n.roles.includes(utilisateur.role)
  )

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100 flex flex-col">
      {/* ── Barre de navigation supérieure ── */}
      <header className="bg-gray-900 border-b border-gray-800 px-6 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-blue-600 flex items-center justify-center font-bold text-sm">H</div>
          <div>
            <span className="font-semibold text-white">HERMES CHU</span>
            <span className="text-xs text-gray-400 ml-2">Système Agentique Hospitalier</span>
          </div>
        </div>

        {/* Navigation centrale */}
        <nav className="hidden md:flex items-center gap-1">
          {navAccessibles.map(item => (
            <NavLink
              key={item.chemin}
              to={item.chemin}
              className={({ isActive }) =>
                `px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-blue-600 text-white'
                    : 'text-gray-400 hover:text-white hover:bg-gray-800'
                }`
              }
            >
              <span className="mr-2">{item.icone}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* Profil utilisateur */}
        <div className="flex items-center gap-3">
          {utilisateur && (
            <div className="hidden md:flex flex-col items-end">
              <span className="text-sm font-medium text-white">
                {utilisateur.prenom} {utilisateur.nom}
              </span>
              <span className="text-xs text-gray-400">
                {utilisateur.service} · {utilisateur.role.replace('ROLE_', '')}
              </span>
            </div>
          )}
          <button
            onClick={handleDeconnexion}
            className="px-3 py-1.5 text-xs text-gray-400 hover:text-white border border-gray-700 hover:border-gray-500 rounded-lg transition-colors"
          >
            Déconnexion
          </button>
        </div>
      </header>

      {/* ── Bandeau de conformité ── */}
      <div className="bg-blue-950 border-b border-blue-900 px-6 py-1.5 flex items-center gap-4 text-xs text-blue-300">
        <span className="flex items-center gap-1">
          <span className="w-2 h-2 rounded-full bg-green-400 inline-block"></span>
          Anonymisation active
        </span>
        <span>·</span>
        <span>ISO 27001 · HDS</span>
        <span>·</span>
        <span>Toutes les interactions sont journalisées</span>
      </div>

      {/* ── Contenu principal ── */}
      <main className="flex-1 overflow-hidden">
        {children}
      </main>
    </div>
  )
}
