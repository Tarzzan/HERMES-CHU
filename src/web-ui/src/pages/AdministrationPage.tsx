import { useState } from 'react'

type OngletAdmin = 'anonymisation' | 'agents' | 'incidents' | 'rapports'

export default function AdministrationPage() {
  const [ongletActif, setOngletActif] = useState<OngletAdmin>('anonymisation')
  const [anonymisationDefaut, setAnonymisationDefaut] = useState(true)
  const [seuilNER, setSeuilNER] = useState(0.85)
  const [justificationModal, setJustificationModal] = useState(false)
  const [justification, setJustification] = useState('')
  const [actionEnAttente, setActionEnAttente] = useState<string | null>(null)

  const onglets: { id: OngletAdmin; label: string; icone: string }[] = [
    { id: 'anonymisation', label: 'Anonymisation', icone: '🔒' },
    { id: 'agents', label: 'Agents', icone: '🤖' },
    { id: 'incidents', label: 'Incidents', icone: '🚨' },
    { id: 'rapports', label: 'Rapports', icone: '📋' },
  ]

  const demanderJustification = (action: string) => {
    setActionEnAttente(action)
    setJustificationModal(true)
  }

  const confirmerAction = () => {
    if (!justification.trim() || justification.length < 20) return
    // TODO: Appel API avec justification
    console.log(`Action: ${actionEnAttente} — Justification: ${justification}`)
    setJustificationModal(false)
    setJustification('')
    setActionEnAttente(null)
  }

  return (
    <div className="flex flex-col h-full overflow-y-auto bg-gray-950 p-6">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-white">Administration</h1>
        <p className="text-sm text-gray-400">Configuration et gestion du système HERMES CHU</p>
      </div>

      {/* Onglets */}
      <div className="flex gap-1 mb-6 bg-gray-900 border border-gray-800 rounded-xl p-1 w-fit">
        {onglets.map(o => (
          <button
            key={o.id}
            onClick={() => setOngletActif(o.id)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              ongletActif === o.id
                ? 'bg-blue-600 text-white'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            <span className="mr-2">{o.icone}</span>
            {o.label}
          </button>
        ))}
      </div>

      {/* Contenu des onglets */}
      {ongletActif === 'anonymisation' && (
        <div className="space-y-6 max-w-2xl">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <h2 className="text-base font-semibold text-white mb-4">Configuration du SAS d'Anonymisation</h2>

            <div className="space-y-5">
              <div className="flex items-center justify-between py-3 border-b border-gray-800">
                <div>
                  <p className="text-sm font-medium text-white">Anonymisation par défaut</p>
                  <p className="text-xs text-gray-400">Active l'anonymisation pour toutes les nouvelles sessions</p>
                </div>
                <button
                  onClick={() => demanderJustification(anonymisationDefaut ? 'DESACTIVER_ANONYMISATION_DEFAUT' : 'ACTIVER_ANONYMISATION_DEFAUT')}
                  className={`relative w-12 h-6 rounded-full transition-colors ${anonymisationDefaut ? 'bg-green-600' : 'bg-red-600'}`}
                >
                  <div className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-transform ${anonymisationDefaut ? 'translate-x-7' : 'translate-x-1'}`} />
                </button>
              </div>

              <div className="py-3 border-b border-gray-800">
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <p className="text-sm font-medium text-white">Seuil de confiance NER</p>
                    <p className="text-xs text-gray-400">Seuil minimum pour la détection d'entités par le modèle NER</p>
                  </div>
                  <span className="text-sm font-bold text-blue-400">{seuilNER}</span>
                </div>
                <input
                  type="range"
                  min={0.5}
                  max={0.99}
                  step={0.01}
                  value={seuilNER}
                  onChange={e => setSeuilNER(parseFloat(e.target.value))}
                  className="w-full accent-blue-500"
                />
                <div className="flex justify-between text-xs text-gray-500 mt-1">
                  <span>0.5 (plus sensible)</span>
                  <span>0.99 (plus précis)</span>
                </div>
              </div>

              <div className="py-3">
                <p className="text-sm font-medium text-white mb-3">Types de PHI actifs</p>
                <div className="grid grid-cols-2 gap-2">
                  {['NOM_PATIENT', 'PRENOM_PATIENT', 'DATE_NAISSANCE', 'NIR', 'ADRESSE', 'TELEPHONE', 'EMAIL', 'IPP', 'NOM_MEDECIN', 'RPPS'].map(type => (
                    <label key={type} className="flex items-center gap-2 text-xs text-gray-300 cursor-pointer">
                      <input type="checkbox" defaultChecked className="accent-blue-500" />
                      {type}
                    </label>
                  ))}
                </div>
              </div>
            </div>

            <div className="mt-5 pt-4 border-t border-gray-800">
              <button
                onClick={() => demanderJustification('SAUVEGARDER_CONFIG_ANONYMISATION')}
                className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white text-sm rounded-lg transition-colors"
              >
                Sauvegarder la configuration
              </button>
            </div>
          </div>

          <div className="bg-amber-950 border border-amber-800 rounded-xl p-4 text-sm text-amber-200">
            <p className="font-semibold mb-1">⚠️ Opération critique</p>
            <p className="text-xs">Toute modification de la configuration d'anonymisation est journalisée avec l'identité de l'opérateur, l'horodatage et la justification. Ces journaux sont immuables et conservés 10 ans.</p>
          </div>
        </div>
      )}

      {ongletActif === 'agents' && (
        <div className="space-y-4 max-w-2xl">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <h2 className="text-base font-semibold text-white mb-4">Gestion des Agents</h2>
            <div className="space-y-3">
              {['Orchestrateur Pilote', 'Agent Clinique', 'Agent Administratif', 'Agent Logistique', 'Agent Recherche', 'Privacy Engine'].map(agent => (
                <div key={agent} className="flex items-center justify-between py-3 border-b border-gray-800 last:border-0">
                  <div>
                    <p className="text-sm font-medium text-white">{agent}</p>
                    <p className="text-xs text-gray-400">v1.0.0 · Hermes-3-Llama-3.1-70B</p>
                  </div>
                  <div className="flex gap-2">
                    <button className="px-3 py-1 text-xs text-gray-300 border border-gray-700 hover:border-gray-500 rounded-lg transition-colors">
                      Redémarrer
                    </button>
                    <button className="px-3 py-1 text-xs text-gray-300 border border-gray-700 hover:border-gray-500 rounded-lg transition-colors">
                      Logs
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {ongletActif === 'rapports' && (
        <div className="space-y-4 max-w-2xl">
          <div className="bg-gray-900 border border-gray-800 rounded-xl p-6">
            <h2 className="text-base font-semibold text-white mb-4">Génération de rapports</h2>
            <div className="space-y-3">
              {[
                { label: 'Rapport hebdomadaire', desc: 'Métriques, incidents et conformité de la semaine' },
                { label: 'Rapport mensuel', desc: 'Bilan complet du mois avec recommandations' },
                { label: 'Rapport de conformité ISO 27001', desc: 'Audit de conformité complet' },
                { label: 'Rapport d\'anonymisation', desc: 'Statistiques détaillées du SAS d\'anonymisation' },
              ].map((r, i) => (
                <div key={i} className="flex items-center justify-between py-3 border-b border-gray-800 last:border-0">
                  <div>
                    <p className="text-sm font-medium text-white">{r.label}</p>
                    <p className="text-xs text-gray-400">{r.desc}</p>
                  </div>
                  <div className="flex gap-2">
                    <button className="px-3 py-1 text-xs text-blue-400 border border-blue-800 hover:border-blue-600 rounded-lg transition-colors">
                      PDF
                    </button>
                    <button className="px-3 py-1 text-xs text-green-400 border border-green-800 hover:border-green-600 rounded-lg transition-colors">
                      Excel
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Modal de justification */}
      {justificationModal && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4">
          <div className="bg-gray-900 border border-gray-700 rounded-2xl p-6 max-w-md w-full">
            <h3 className="text-base font-semibold text-white mb-2">Justification requise</h3>
            <p className="text-sm text-gray-400 mb-4">
              Cette opération critique nécessite une justification (minimum 20 caractères). Elle sera journalisée avec votre identité.
            </p>
            <textarea
              value={justification}
              onChange={e => setJustification(e.target.value)}
              placeholder="Décrivez la raison de cette modification…"
              rows={4}
              className="w-full bg-gray-800 border border-gray-700 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 resize-none outline-none focus:border-blue-500 mb-4"
            />
            <div className="flex justify-between items-center">
              <span className={`text-xs ${justification.length >= 20 ? 'text-green-400' : 'text-gray-500'}`}>
                {justification.length}/20 caractères minimum
              </span>
              <div className="flex gap-3">
                <button
                  onClick={() => { setJustificationModal(false); setJustification('') }}
                  className="px-4 py-2 text-sm text-gray-400 hover:text-white transition-colors"
                >
                  Annuler
                </button>
                <button
                  onClick={confirmerAction}
                  disabled={justification.length < 20}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-700 disabled:text-gray-500 text-white text-sm rounded-lg transition-colors"
                >
                  Confirmer
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
