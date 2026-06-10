import { useState, FormEvent } from 'react'
import { useAuth } from '../contexts/AuthContext'

export default function LoginPage() {
  const { connexion, erreurConnexion } = useAuth()
  const [identifiant, setIdentifiant] = useState('')
  const [motDePasse, setMotDePasse] = useState('')
  const [enChargement, setEnChargement] = useState(false)

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault()
    setEnChargement(true)
    await connexion(identifiant, motDePasse)
    setEnChargement(false)
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-blue-600 flex items-center justify-center text-3xl font-bold text-white mx-auto mb-4">
            H
          </div>
          <h1 className="text-2xl font-bold text-white">HERMES CHU</h1>
          <p className="text-gray-400 text-sm mt-1">Système Agentique Hospitalier Souverain</p>
        </div>

        {/* Formulaire */}
        <div className="bg-gray-900 border border-gray-800 rounded-2xl p-8">
          <h2 className="text-lg font-semibold text-white mb-6">Connexion</h2>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm text-gray-400 mb-1.5">Identifiant</label>
              <input
                type="text"
                value={identifiant}
                onChange={e => setIdentifiant(e.target.value)}
                placeholder="Identifiant CHU"
                required
                className="w-full bg-gray-800 border border-gray-700 focus:border-blue-500 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 outline-none transition-colors"
              />
            </div>

            <div>
              <label className="block text-sm text-gray-400 mb-1.5">Mot de passe</label>
              <input
                type="password"
                value={motDePasse}
                onChange={e => setMotDePasse(e.target.value)}
                placeholder="••••••••"
                required
                className="w-full bg-gray-800 border border-gray-700 focus:border-blue-500 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 outline-none transition-colors"
              />
            </div>

            {erreurConnexion && (
              <div className="px-4 py-3 bg-red-950 border border-red-800 rounded-xl text-sm text-red-300">
                {erreurConnexion}
              </div>
            )}

            <button
              type="submit"
              disabled={enChargement || !identifiant || !motDePasse}
              className="w-full py-3 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-700 disabled:text-gray-500 text-white font-medium rounded-xl transition-colors flex items-center justify-center gap-2"
            >
              {enChargement ? (
                <span className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : null}
              Se connecter
            </button>
          </form>

          <div className="mt-6 pt-5 border-t border-gray-800">
            <p className="text-xs text-gray-500 text-center mb-3">Authentification via Keycloak (SSO CHU)</p>
            <button className="w-full py-2.5 border border-gray-700 hover:border-gray-500 text-gray-300 hover:text-white text-sm rounded-xl transition-colors">
              Connexion SSO CHU
            </button>
          </div>

          {/* Démo */}
          <div className="mt-4 p-3 bg-blue-950 border border-blue-900 rounded-xl text-xs text-blue-300">
            <p className="font-medium mb-1">Mode démonstration</p>
            <p>Identifiant : <code className="text-blue-200">demo</code> · Mot de passe : <code className="text-blue-200">demo</code></p>
          </div>
        </div>

        <p className="text-center text-xs text-gray-600 mt-6">
          HERMES CHU v1.0.0 · ISO 27001 · HDS · Toutes les connexions sont journalisées
        </p>
      </div>
    </div>
  )
}
