/**
 * HERMES CHU Desktop — Page des Agents Spécialisés
 * ==================================================
 * Affiche et permet d'activer les 5 agents hospitaliers CHU.
 * Intégration : injecter dans app/agents/index.tsx de hermes-desktop
 * via le système de slots/plugins natif de hermes-agent.
 */

import React, { useState } from 'react'

// ---------------------------------------------------------------------------
// Définition des agents CHU
// ---------------------------------------------------------------------------

const AGENTS_CHU = [
  {
    id: 'clinique',
    nom: 'Agent Clinique',
    emoji: '🩺',
    couleur: 'blue',
    description: 'Analyse les comptes-rendus médicaux, aide à la décision clinique et synthétise les dossiers patients.',
    capacites: [
      'Synthèse de dossier patient (DPI)',
      'Aide à la décision diagnostique',
      'Analyse de résultats biologiques',
      'Recherche bibliographique médicale',
      'Génération de comptes-rendus',
    ],
    outils: ['FHIR R4 (lecture)', 'PubMed', 'Thériaque', 'CIM-10'],
    restrictions: ['Aucune prescription directe', 'Validation médecin obligatoire'],
    skill: 'agent_clinique.md',
    actif: true,
  },
  {
    id: 'administratif',
    nom: 'Agent Administratif',
    emoji: '📋',
    couleur: 'green',
    description: 'Gère les tâches administratives : admissions, courriers, planification et facturation.',
    capacites: [
      'Rédaction de courriers médicaux',
      'Gestion des admissions/sorties',
      'Planification des rendez-vous',
      'Aide à la facturation (CCAM, GHM)',
      'Gestion des formulaires ALD',
    ],
    outils: ['GAM', 'FHIR R4 (écriture admin)', 'Messagerie sécurisée MSSanté'],
    restrictions: ['Pas d\'accès aux données cliniques sensibles'],
    skill: 'agent_administratif.md',
    actif: true,
  },
  {
    id: 'logistique',
    nom: 'Agent Logistique',
    emoji: '📦',
    couleur: 'orange',
    description: 'Optimise la gestion des stocks, des équipements et des flux logistiques hospitaliers.',
    capacites: [
      'Suivi des stocks de médicaments',
      'Gestion des équipements biomédicaux',
      'Optimisation des flux de stérilisation',
      'Alertes de rupture de stock',
      'Planification des maintenances',
    ],
    outils: ['SIL (Système d\'Information de Laboratoire)', 'GMAO', 'Pharmacie'],
    restrictions: ['Pas d\'accès aux dossiers patients'],
    skill: 'agent_logistique.md',
    actif: false,
  },
  {
    id: 'recherche',
    nom: 'Agent Recherche',
    emoji: '🔬',
    couleur: 'purple',
    description: 'Assiste les équipes de recherche clinique : protocoles, bibliographie et analyse de cohortes.',
    capacites: [
      'Recherche bibliographique avancée',
      'Aide à la rédaction de protocoles',
      'Analyse statistique descriptive',
      'Veille réglementaire (ANSM, HAS)',
      'Extraction de données de cohortes',
    ],
    outils: ['PubMed', 'ClinicalTrials.gov', 'SNDS (données anonymisées)', 'R/Python'],
    restrictions: ['Données de recherche uniquement', 'Anonymisation renforcée obligatoire'],
    skill: 'agent_recherche.md',
    actif: false,
  },
  {
    id: 'qualite',
    nom: 'Agent Qualité',
    emoji: '✅',
    couleur: 'teal',
    description: 'Surveille les indicateurs qualité, analyse les événements indésirables et prépare les audits.',
    capacites: [
      'Suivi des indicateurs IPAQSS',
      'Analyse des événements indésirables (EIG)',
      'Préparation des audits HAS/ISO',
      'Tableau de bord qualité temps réel',
      'Génération de rapports de conformité',
    ],
    outils: ['APIs Qualité CHU', 'Journal d\'audit ISO 27001', 'OSIRIS'],
    restrictions: ['Accès en lecture seule aux dossiers'],
    skill: 'agent_qualite.md',
    actif: true,
  },
]

const COULEURS: Record<string, { bg: string; border: string; badge: string; dot: string }> = {
  blue:   { bg: 'bg-blue-50',   border: 'border-blue-200',   badge: 'bg-blue-100 text-blue-700',   dot: 'bg-blue-500' },
  green:  { bg: 'bg-green-50',  border: 'border-green-200',  badge: 'bg-green-100 text-green-700', dot: 'bg-green-500' },
  orange: { bg: 'bg-orange-50', border: 'border-orange-200', badge: 'bg-orange-100 text-orange-700', dot: 'bg-orange-500' },
  purple: { bg: 'bg-purple-50', border: 'border-purple-200', badge: 'bg-purple-100 text-purple-700', dot: 'bg-purple-500' },
  teal:   { bg: 'bg-teal-50',   border: 'border-teal-200',   badge: 'bg-teal-100 text-teal-700',   dot: 'bg-teal-500' },
}

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export function ChuAgentsPage() {
  const [agents, setAgents] = useState(AGENTS_CHU)
  const [selected, setSelected] = useState<string | null>(null)

  const toggleAgent = (id: string) => {
    setAgents(prev => prev.map(a => a.id === id ? { ...a, actif: !a.actif } : a))
  }

  const selectedAgent = agents.find(a => a.id === selected)

  return (
    <div className="flex h-full">
      {/* Liste des agents */}
      <div className="w-80 border-r overflow-y-auto p-4 space-y-3">
        <div className="mb-4">
          <h2 className="text-lg font-bold text-gray-900">Agents CHU</h2>
          <p className="text-sm text-gray-500">
            {agents.filter(a => a.actif).length}/{agents.length} agents actifs
          </p>
        </div>

        {agents.map(agent => {
          const c = COULEURS[agent.couleur]
          return (
            <div
              key={agent.id}
              onClick={() => setSelected(agent.id)}
              className={`p-3 rounded-lg border cursor-pointer transition-all ${
                selected === agent.id ? `${c.bg} ${c.border}` : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-xl">{agent.emoji}</span>
                  <div>
                    <p className="font-medium text-sm">{agent.nom}</p>
                    <p className="text-xs text-gray-500 truncate max-w-[160px]">{agent.description.slice(0, 50)}…</p>
                  </div>
                </div>
                <div
                  onClick={e => { e.stopPropagation(); toggleAgent(agent.id) }}
                  className={`relative inline-flex h-5 w-9 items-center rounded-full cursor-pointer transition-colors ${
                    agent.actif ? 'bg-blue-600' : 'bg-gray-300'
                  }`}
                >
                  <span className={`inline-block h-3 w-3 transform rounded-full bg-white transition-transform ${
                    agent.actif ? 'translate-x-5' : 'translate-x-1'
                  }`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Détail de l'agent sélectionné */}
      <div className="flex-1 overflow-y-auto p-6">
        {selectedAgent ? (
          <div>
            <div className="flex items-center gap-3 mb-6">
              <span className="text-4xl">{selectedAgent.emoji}</span>
              <div>
                <h2 className="text-2xl font-bold">{selectedAgent.nom}</h2>
                <p className="text-gray-500">{selectedAgent.description}</p>
              </div>
              <div className={`ml-auto px-3 py-1 rounded-full text-sm font-medium ${
                selectedAgent.actif ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'
              }`}>
                {selectedAgent.actif ? '● Actif' : '○ Inactif'}
              </div>
            </div>

            {/* Capacités */}
            <div className="mb-6">
              <h3 className="font-semibold text-gray-700 mb-3">Capacités</h3>
              <div className="space-y-2">
                {selectedAgent.capacites.map((cap, i) => (
                  <div key={i} className="flex items-center gap-2 text-sm">
                    <span className={`h-2 w-2 rounded-full ${COULEURS[selectedAgent.couleur].dot}`} />
                    {cap}
                  </div>
                ))}
              </div>
            </div>

            {/* Outils */}
            <div className="mb-6">
              <h3 className="font-semibold text-gray-700 mb-3">Outils & Intégrations</h3>
              <div className="flex flex-wrap gap-2">
                {selectedAgent.outils.map((outil, i) => (
                  <span key={i} className={`px-2 py-1 rounded text-xs font-medium ${COULEURS[selectedAgent.couleur].badge}`}>
                    {outil}
                  </span>
                ))}
              </div>
            </div>

            {/* Restrictions */}
            <div className="mb-6">
              <h3 className="font-semibold text-gray-700 mb-3">Garde-fous & Restrictions</h3>
              <div className="space-y-2">
                {selectedAgent.restrictions.map((r, i) => (
                  <div key={i} className="flex items-center gap-2 text-sm text-amber-700">
                    <span>⚠️</span>
                    {r}
                  </div>
                ))}
              </div>
            </div>

            {/* Skill source */}
            <div className="bg-gray-50 rounded-lg p-4">
              <p className="text-xs text-gray-500">
                Skill hermes-agent : <code className="bg-gray-200 px-1 rounded">chu/skills/{selectedAgent.skill}</code>
              </p>
            </div>

            <div className="mt-6 flex gap-3">
              <button
                onClick={() => toggleAgent(selectedAgent.id)}
                className={`px-4 py-2 rounded font-medium text-sm transition ${
                  selectedAgent.actif
                    ? 'bg-red-100 text-red-700 hover:bg-red-200'
                    : 'bg-blue-600 text-white hover:bg-blue-700'
                }`}
              >
                {selectedAgent.actif ? 'Désactiver l\'agent' : 'Activer l\'agent'}
              </button>
              <button className="px-4 py-2 border rounded text-sm hover:bg-gray-50">
                Configurer le skill
              </button>
            </div>
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center h-full text-gray-400">
            <span className="text-5xl mb-4">🤖</span>
            <p className="text-lg font-medium">Sélectionnez un agent</p>
            <p className="text-sm">Cliquez sur un agent dans la liste pour voir ses détails</p>
          </div>
        )}
      </div>
    </div>
  )
}
