/**
 * HERMES CHU Desktop — Panneau Privacy Engine RGPD
 * ===================================================
 * Composant React intégré dans l'interface Electron.
 * Permet d'activer/désactiver l'anonymisation et de gérer
 * le mode Glass-Break avec justification obligatoire.
 *
 * Intégration : injecter dans app/settings/index.tsx de hermes-desktop
 * via le système de plugins/slots natif de hermes-agent.
 */

import React, { useEffect, useState } from 'react'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface PrivacyStatus {
  actif: boolean
  glass_break_actif: boolean
  glass_break_justification?: string
  glass_break_expire_dans?: number
  nb_sessions_actives: number
  nb_entites_anonymisees_total: number
}

// Bridge IPC exposé par electron/chu-preload.cjs (absent en mode web)
declare global {
  interface Window {
    hermeschu?: {
      privacy: {
        status: () => Promise<{ ok: boolean; data?: any; error?: string }>
        toggle: (actif: boolean) => Promise<{ ok: boolean; data?: any; error?: string }>
        glassBreak: (args: { justification: string; duree_minutes: number }) => Promise<{ ok: boolean; data?: any; error?: string }>
      }
      metrics: {
        anonymisation: () => Promise<{ ok: boolean; data?: any; error?: string }>
      }
    }
  }
}

// Fallback HTTP quand le bridge IPC n'est pas disponible (mode web / dev)
const API_BASE =
  (typeof import.meta !== 'undefined' && (import.meta as any).env?.VITE_CHU_API_BASE) ||
  'http://localhost:8001'

// L'API renvoie { actif, glass_break, glass_break_details, journal_entrees } —
// on la normalise vers la forme attendue par le panneau.
function normaliserStatut(brut: any, stats?: any): PrivacyStatus {
  const details = brut?.glass_break_details
  let expireDans: number | undefined
  if (details?.debut && details?.duree_secondes) {
    expireDans = Math.max(0, details.debut + details.duree_secondes - Date.now() / 1000)
  }
  return {
    actif: Boolean(brut?.actif),
    glass_break_actif: Boolean(brut?.glass_break),
    glass_break_justification: details?.justification,
    glass_break_expire_dans: expireDans,
    nb_sessions_actives: stats?.sessions_avec_phi ?? 0,
    nb_entites_anonymisees_total: stats?.total_entites_phi_detectees ?? 0,
  }
}

// ---------------------------------------------------------------------------
// Hook — Communication avec l'API CHU (bridge IPC ou HTTP)
// ---------------------------------------------------------------------------

function usePrivacyEngine() {
  const [status, setStatus] = useState<PrivacyStatus | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchStatus = async () => {
    try {
      let brut: any
      let stats: any
      if (window.hermeschu) {
        const [resStatut, resStats] = await Promise.all([
          window.hermeschu.privacy.status(),
          window.hermeschu.metrics.anonymisation(),
        ])
        if (!resStatut.ok) throw new Error(resStatut.error)
        brut = resStatut.data
        stats = resStats.ok ? resStats.data : undefined
      } else {
        const res = await fetch(`${API_BASE}/api/chu/privacy/statut`)
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        brut = await res.json()
        const resStats = await fetch(`${API_BASE}/api/chu/anonymisation/stats`)
        stats = resStats.ok ? await resStats.json() : undefined
      }
      setStatus(normaliserStatut(brut, stats))
      setError(null)
    } catch (e) {
      setError('API CHU indisponible — vérifiez que le serveur est démarré')
    } finally {
      setLoading(false)
    }
  }

  const toggle = async (actif: boolean) => {
    if (window.hermeschu) {
      const res = await window.hermeschu.privacy.toggle(actif)
      if (res.ok) fetchStatus()
      return
    }
    const res = await fetch(`${API_BASE}/api/chu/privacy/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ actif }),
    })
    if (res.ok) fetchStatus()
  }

  const activerGlassBreak = async (justification: string, duree: number) => {
    if (window.hermeschu) {
      const res = await window.hermeschu.privacy.glassBreak({ justification, duree_minutes: duree })
      if (res.ok) fetchStatus()
      return res.ok
    }
    const res = await fetch(`${API_BASE}/api/chu/privacy/glass-break`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ justification, duree_minutes: duree }),
    })
    if (res.ok) fetchStatus()
    return res.ok
  }

  useEffect(() => {
    fetchStatus()
    const interval = setInterval(fetchStatus, 10_000)
    return () => clearInterval(interval)
  }, [])

  return { status, loading, error, toggle, activerGlassBreak, refresh: fetchStatus }
}

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export function PrivacyPanel() {
  const { status, loading, error, toggle, activerGlassBreak } = usePrivacyEngine()
  const [showGlassBreak, setShowGlassBreak] = useState(false)
  const [justification, setJustification] = useState('')
  const [duree, setDuree] = useState(30)
  const [glassBreakError, setGlassBreakError] = useState('')

  const handleGlassBreak = async () => {
    if (justification.length < 20) {
      setGlassBreakError('La justification doit contenir au moins 20 caractères.')
      return
    }
    const ok = await activerGlassBreak(justification, duree)
    if (ok) {
      setShowGlassBreak(false)
      setJustification('')
      setGlassBreakError('')
    } else {
      setGlassBreakError('Échec de l\'activation du Glass-Break.')
    }
  }

  if (loading) {
    return (
      <div className="p-6 flex items-center gap-3 text-gray-500">
        <div className="animate-spin h-5 w-5 border-2 border-blue-500 border-t-transparent rounded-full" />
        Connexion au Privacy Engine…
      </div>
    )
  }

  if (error) {
    return (
      <div className="p-6">
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <p className="text-red-700 font-medium">⚠️ {error}</p>
          <p className="text-sm text-red-500 mt-1">
            Lancez <code className="bg-red-100 px-1 rounded">./chu/installer_chu.sh --poc</code> pour démarrer le serveur.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="p-6 max-w-2xl">
      {/* En-tête */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h2 className="text-xl font-bold text-gray-900">Privacy Engine — Anonymisation RGPD</h2>
          <p className="text-sm text-gray-500 mt-1">
            Anonymise les données de santé (PHI) avant envoi au modèle IA.
          </p>
        </div>
        <div className={`px-3 py-1 rounded-full text-sm font-medium ${
          status?.actif ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
        }`}>
          {status?.actif ? '🔒 Actif' : '🔓 Inactif'}
        </div>
      </div>

      {/* Alerte Glass-Break actif */}
      {status?.glass_break_actif && (
        <div className="mb-4 bg-amber-50 border border-amber-300 rounded-lg p-4">
          <p className="font-semibold text-amber-800">
            ⚠️ MODE GLASS-BREAK ACTIF
          </p>
          <p className="text-sm text-amber-700 mt-1">
            Justification : <em>{status.glass_break_justification}</em>
          </p>
          {status.glass_break_expire_dans && (
            <p className="text-sm text-amber-600 mt-1">
              Expire dans : {Math.ceil(status.glass_break_expire_dans / 60)} min
            </p>
          )}
          <p className="text-xs text-amber-500 mt-2">
            Cet événement est journalisé de manière immuable dans le journal d'audit ISO 27001.
          </p>
        </div>
      )}

      {/* Statistiques */}
      <div className="grid grid-cols-2 gap-4 mb-6">
        <div className="bg-gray-50 rounded-lg p-4">
          <p className="text-2xl font-bold text-blue-600">{status?.nb_entites_anonymisees_total ?? 0}</p>
          <p className="text-sm text-gray-500">Entités PHI anonymisées</p>
        </div>
        <div className="bg-gray-50 rounded-lg p-4">
          <p className="text-2xl font-bold text-blue-600">{status?.nb_sessions_actives ?? 0}</p>
          <p className="text-sm text-gray-500">Sessions actives</p>
        </div>
      </div>

      {/* Toggle principal */}
      <div className="flex items-center justify-between p-4 border rounded-lg mb-4">
        <div>
          <p className="font-medium">Anonymisation automatique</p>
          <p className="text-sm text-gray-500">
            Détecte et pseudonymise NIR, IPP, noms, adresses, téléphones
          </p>
        </div>
        <button
          onClick={() => toggle(!status?.actif)}
          className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
            status?.actif ? 'bg-blue-600' : 'bg-gray-300'
          }`}
        >
          <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
            status?.actif ? 'translate-x-6' : 'translate-x-1'
          }`} />
        </button>
      </div>

      {/* Bouton Glass-Break */}
      {!showGlassBreak ? (
        <button
          onClick={() => setShowGlassBreak(true)}
          className="w-full p-3 border border-amber-300 text-amber-700 rounded-lg hover:bg-amber-50 transition text-sm font-medium"
        >
          🔓 Activer le Mode Glass-Break (urgence médicale)
        </button>
      ) : (
        <div className="border border-amber-300 rounded-lg p-4 bg-amber-50">
          <h3 className="font-semibold text-amber-800 mb-3">Mode Glass-Break — Désactivation temporaire</h3>
          <p className="text-xs text-amber-700 mb-3">
            Cette action sera journalisée de manière immuable avec votre identité, la date et la justification.
          </p>

          <div className="space-y-3">
            <div>
              <label className="block text-sm font-medium mb-1">Justification médicale (obligatoire)</label>
              <textarea
                className="w-full p-2 border rounded text-sm"
                rows={3}
                placeholder="Ex : Urgence vitale nécessitant l'accès aux données nominatives pour identification du patient…"
                value={justification}
                onChange={e => setJustification(e.target.value)}
              />
              <p className="text-xs text-gray-400 mt-1">{justification.length}/20 caractères minimum</p>
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Durée (minutes)</label>
              <input
                type="number"
                min={1}
                max={60}
                value={duree}
                onChange={e => setDuree(Number(e.target.value))}
                className="w-24 p-2 border rounded text-sm"
              />
            </div>

            {glassBreakError && (
              <p className="text-red-600 text-sm">{glassBreakError}</p>
            )}

            <div className="flex gap-3">
              <button
                onClick={handleGlassBreak}
                className="bg-amber-600 text-white px-4 py-2 rounded text-sm font-medium hover:bg-amber-700"
              >
                Confirmer & Journaliser
              </button>
              <button
                onClick={() => { setShowGlassBreak(false); setJustification(''); setGlassBreakError('') }}
                className="px-4 py-2 border rounded text-sm hover:bg-gray-50"
              >
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
