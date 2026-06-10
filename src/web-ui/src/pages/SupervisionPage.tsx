import { useState, useEffect } from 'react'

interface StatutAgent {
  nom: string
  statut: 'ACTIF' | 'INACTIF' | 'ERREUR' | 'MAINTENANCE'
  requetesEnCours: number
  latenceMoyenneMs: number
  tauxErreurPct: number
  derniereActivite: string
}

interface MetriquesCles {
  requetesDerniereHeure: number
  tauxSuccesPct: number
  latenceP95Ms: number
  gardeFousDerniereHeure: number
  incidentsOuverts: number
  anonymisationActive: boolean
  statutGlobal: string
}

const AGENTS_DEMO: StatutAgent[] = [
  { nom: 'Orchestrateur Pilote', statut: 'ACTIF', requetesEnCours: 3, latenceMoyenneMs: 2340, tauxErreurPct: 3.9, derniereActivite: 'Il y a 2s' },
  { nom: 'Agent Clinique', statut: 'ACTIF', requetesEnCours: 1, latenceMoyenneMs: 3200, tauxErreurPct: 2.1, derniereActivite: 'Il y a 15s' },
  { nom: 'Agent Administratif', statut: 'ACTIF', requetesEnCours: 0, latenceMoyenneMs: 1800, tauxErreurPct: 1.5, derniereActivite: 'Il y a 1min' },
  { nom: 'Agent Logistique', statut: 'ACTIF', requetesEnCours: 2, latenceMoyenneMs: 1200, tauxErreurPct: 0.8, derniereActivite: 'Il y a 8s' },
  { nom: 'Agent Recherche', statut: 'ACTIF', requetesEnCours: 0, latenceMoyenneMs: 4500, tauxErreurPct: 4.2, derniereActivite: 'Il y a 3min' },
  { nom: 'Privacy Engine', statut: 'ACTIF', requetesEnCours: 5, latenceMoyenneMs: 45, tauxErreurPct: 0.1, derniereActivite: 'Il y a 1s' },
]

const METRIQUES_DEMO: MetriquesCles = {
  requetesDerniereHeure: 187,
  tauxSuccesPct: 96.8,
  latenceP95Ms: 4800,
  gardeFousDerniereHeure: 2,
  incidentsOuverts: 1,
  anonymisationActive: true,
  statutGlobal: 'OPÉRATIONNEL',
}

function BadgeStatut({ statut }: { statut: string }) {
  const couleurs: Record<string, string> = {
    ACTIF: 'bg-green-900 text-green-300 border-green-700',
    INACTIF: 'bg-gray-800 text-gray-400 border-gray-600',
    ERREUR: 'bg-red-900 text-red-300 border-red-700',
    MAINTENANCE: 'bg-yellow-900 text-yellow-300 border-yellow-700',
    OPÉRATIONNEL: 'bg-green-900 text-green-300 border-green-700',
  }
  const points: Record<string, string> = {
    ACTIF: 'bg-green-400',
    INACTIF: 'bg-gray-400',
    ERREUR: 'bg-red-400 animate-pulse',
    MAINTENANCE: 'bg-yellow-400',
    OPÉRATIONNEL: 'bg-green-400',
  }
  return (
    <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs border ${couleurs[statut] || couleurs.INACTIF}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${points[statut] || points.INACTIF}`} />
      {statut}
    </span>
  )
}

function CarteMetrique({ titre, valeur, unite, couleur, icone }: {
  titre: string; valeur: string | number; unite?: string; couleur: string; icone: string
}) {
  return (
    <div className={`bg-gray-900 border rounded-xl p-5 ${couleur}`}>
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs text-gray-400 mb-1">{titre}</p>
          <p className="text-2xl font-bold text-white">
            {valeur}
            {unite && <span className="text-sm font-normal text-gray-400 ml-1">{unite}</span>}
          </p>
        </div>
        <span className="text-2xl">{icone}</span>
      </div>
    </div>
  )
}

export default function SupervisionPage() {
  const [agents, setAgents] = useState<StatutAgent[]>(AGENTS_DEMO)
  const [metriques, setMetriques] = useState<MetriquesCles>(METRIQUES_DEMO)
  const [derniereMaj, setDerniereMaj] = useState(new Date())

  // Simulation de mise à jour en temps réel
  useEffect(() => {
    const intervalle = setInterval(() => {
      setDerniereMaj(new Date())
      setMetriques(prev => ({
        ...prev,
        requetesDerniereHeure: prev.requetesDerniereHeure + Math.floor(Math.random() * 3),
        latenceP95Ms: 4500 + Math.floor(Math.random() * 600),
      }))
    }, 5000)
    return () => clearInterval(intervalle)
  }, [])

  return (
    <div className="flex flex-col h-full overflow-y-auto bg-gray-950 p-6 space-y-6">
      {/* En-tête */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">Supervision Système</h1>
          <p className="text-sm text-gray-400">Tableau de bord en temps réel — HERMES CHU</p>
        </div>
        <div className="flex items-center gap-3">
          <BadgeStatut statut={metriques.statutGlobal} />
          <span className="text-xs text-gray-500">
            Mis à jour : {derniereMaj.toLocaleTimeString('fr-FR')}
          </span>
        </div>
      </div>

      {/* Métriques clés */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <CarteMetrique titre="Requêtes / heure" valeur={metriques.requetesDerniereHeure} couleur="border-gray-800" icone="📨" />
        <CarteMetrique titre="Taux de succès" valeur={metriques.tauxSuccesPct} unite="%" couleur="border-green-900" icone="✅" />
        <CarteMetrique titre="Latence P95" valeur={metriques.latenceP95Ms} unite="ms" couleur="border-gray-800" icone="⚡" />
        <CarteMetrique titre="Garde-fous / h" valeur={metriques.gardeFousDerniereHeure} couleur="border-yellow-900" icone="🛡️" />
        <CarteMetrique titre="Incidents ouverts" valeur={metriques.incidentsOuverts} couleur={metriques.incidentsOuverts > 0 ? "border-red-900" : "border-gray-800"} icone="🚨" />
        <CarteMetrique titre="Anonymisation" valeur={metriques.anonymisationActive ? 'Active' : 'Désactivée'} couleur={metriques.anonymisationActive ? "border-green-900" : "border-red-900"} icone="🔒" />
      </div>

      {/* Statut des agents */}
      <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden">
        <div className="px-5 py-4 border-b border-gray-800">
          <h2 className="text-sm font-semibold text-white">Statut des agents</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-xs text-gray-500 border-b border-gray-800">
                <th className="text-left px-5 py-3">Agent</th>
                <th className="text-left px-5 py-3">Statut</th>
                <th className="text-right px-5 py-3">Requêtes en cours</th>
                <th className="text-right px-5 py-3">Latence moy.</th>
                <th className="text-right px-5 py-3">Taux d'erreur</th>
                <th className="text-right px-5 py-3">Dernière activité</th>
              </tr>
            </thead>
            <tbody>
              {agents.map((agent, i) => (
                <tr key={i} className="border-b border-gray-800 hover:bg-gray-800/50 transition-colors">
                  <td className="px-5 py-3 font-medium text-white">{agent.nom}</td>
                  <td className="px-5 py-3"><BadgeStatut statut={agent.statut} /></td>
                  <td className="px-5 py-3 text-right text-gray-300">{agent.requetesEnCours}</td>
                  <td className="px-5 py-3 text-right text-gray-300">{agent.latenceMoyenneMs.toLocaleString()} ms</td>
                  <td className={`px-5 py-3 text-right font-medium ${agent.tauxErreurPct > 5 ? 'text-red-400' : agent.tauxErreurPct > 2 ? 'text-yellow-400' : 'text-green-400'}`}>
                    {agent.tauxErreurPct}%
                  </td>
                  <td className="px-5 py-3 text-right text-gray-500 text-xs">{agent.derniereActivite}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Activité des garde-fous */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <h2 className="text-sm font-semibold text-white mb-4">Déclenchements de garde-fous (7 jours)</h2>
          <div className="space-y-3">
            {[
              { niveau: 'Niveau 1 — Input', nb: 8, couleur: 'bg-yellow-500' },
              { niveau: 'Niveau 2 — Tool Call', nb: 3, couleur: 'bg-orange-500' },
              { niveau: 'Niveau 3 — Output', nb: 1, couleur: 'bg-red-500' },
              { niveau: 'Niveau 4 — Bounded Exec.', nb: 0, couleur: 'bg-purple-500' },
            ].map((item, i) => (
              <div key={i}>
                <div className="flex justify-between text-xs text-gray-400 mb-1">
                  <span>{item.niveau}</span>
                  <span className="font-medium text-white">{item.nb}</span>
                </div>
                <div className="h-2 bg-gray-800 rounded-full overflow-hidden">
                  <div
                    className={`h-full ${item.couleur} rounded-full transition-all`}
                    style={{ width: `${Math.min(item.nb * 10, 100)}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <h2 className="text-sm font-semibold text-white mb-4">Entités PHI anonymisées (7 jours)</h2>
          <div className="space-y-2">
            {[
              { type: 'Noms patients', nb: 4639, pct: 52 },
              { type: 'IPP', nb: 1456, pct: 16 },
              { type: 'Dates naissance', nb: 876, pct: 10 },
              { type: 'NIR', nb: 423, pct: 5 },
              { type: 'Téléphones', nb: 234, pct: 3 },
              { type: 'Autres', nb: 1306, pct: 14 },
            ].map((item, i) => (
              <div key={i} className="flex items-center gap-3 text-xs">
                <span className="text-gray-400 w-32 truncate">{item.type}</span>
                <div className="flex-1 h-1.5 bg-gray-800 rounded-full overflow-hidden">
                  <div className="h-full bg-blue-500 rounded-full" style={{ width: `${item.pct}%` }} />
                </div>
                <span className="text-gray-300 w-12 text-right">{item.nb.toLocaleString()}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
