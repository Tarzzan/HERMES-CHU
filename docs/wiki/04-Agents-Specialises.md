<div align="center">
  <h1 style="color: #0052cc;">🤖 Réseau d'Agents Spécialisés</h1>
</div>

<br/>

Le réseau d'agents spécialisés constitue la force de frappe opérationnelle de HERMES CHU. Chaque agent est un conteneur isolé, disposant de son propre jeu d'outils et de son propre system prompt. L'Agent Pilote (orchestrateur) leur délègue des tâches via le mécanisme de Function Calling.

## Catalogue des Agents

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #6366f1; color: white;">
      <th style="padding: 12px; text-align: left;">Agent</th>
      <th style="padding: 12px; text-align: left;">Domaine</th>
      <th style="padding: 12px; text-align: left;">Outils Principaux</th>
      <th style="padding: 12px; text-align: center;">Accès DPI</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Clinique</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Synthèse médicale, préparation RCP, aide au codage PMSI</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>lire_dossier_patient</code>, <code>generer_synthese</code>, <code>proposer_codage_cim10</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">Lecture</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Administratif</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Gestion documentaire, courriers, planification</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>generer_courrier</code>, <code>planifier_rdv</code>, <code>rechercher_protocole</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">Non</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Logistique</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Gestion des lits, flux patients, approvisionnement</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>consulter_occupation_lits</code>, <code>prevoir_flux</code>, <code>commander_stock</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">Non</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Recherche</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Veille bibliographique, analyse de cohortes</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>rechercher_pubmed</code>, <code>analyser_cohorte</code>, <code>resumer_article</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">Anonymisé</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Qualité</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Indicateurs IPAQSS, audits internes, non-conformités</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>calculer_indicateur</code>, <code>generer_rapport_audit</code>, <code>suivre_action_corrective</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">Agrégé</td>
    </tr>
  </tbody>
</table>

## Principe d'Isolation

Chaque agent s'exécute dans un conteneur Docker dédié avec :
- **Réseau isolé** : Aucune communication directe entre agents. Toute interaction passe par l'orchestrateur.
- **Outils restreints** : Un agent ne peut appeler que les outils définis dans son manifeste.
- **Budget tokens** : Chaque agent dispose d'un budget de tokens limité par requête.
- **Timeout** : Limite de 60 secondes par exécution d'agent.

## Mécanisme de Délégation

L'Agent Pilote délègue via un appel de fonction structuré :

```json
{
  "name": "deleguer_agent",
  "parameters": {
    "agent": "clinique",
    "tache": "Générer une synthèse médicale pour le patient [PATIENT_A]",
    "contexte": "Préparation RCP oncologie du 15/06/2026",
    "priorite": "haute",
    "timeout_secondes": 45
  }
}
```

L'agent spécialisé reçoit la tâche déjà anonymisée, exécute ses outils, et retourne le résultat à l'orchestrateur qui le réhydrate avant affichage.
