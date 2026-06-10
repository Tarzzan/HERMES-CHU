<div align="center">
  <h1 style="color: #0052cc;">💻 Interface Web de Pilotage</h1>
</div>

<br/>

L'interface web de HERMES CHU est conçue comme un centre de commande unifié, inspiré des interfaces de Manus et Ollama, mais adaptée aux besoins spécifiques du milieu hospitalier. Elle permet à la fois le dialogue avec l'orchestrateur et la supervision en temps réel de l'ensemble du système agentique.

## Architecture de l'Interface

L'interface est construite en **React 18 + TypeScript + TailwindCSS** et communique avec le backend via WebSocket (temps réel) et REST (opérations CRUD). Elle est divisée en trois espaces distincts, accessibles selon le rôle de l'utilisateur.

## Espace 1 — Dialogue (Chat Orchestrateur)

L'espace principal est une interface conversationnelle permettant d'interagir avec l'Agent Pilote :

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <thead>
    <tr style="background-color: #10b981; color: white;">
      <th style="padding: 12px; text-align: left;">Fonctionnalité</th>
      <th style="padding: 12px; text-align: left;">Description</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Chat multimodal</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Texte, fichiers PDF, images (radiologies) en entrée.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Streaming temps réel</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Affichage token par token via WebSocket (SSE fallback).</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Thinking visible</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Panneau latéral montrant le raisonnement de l'agent en temps réel.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Human-in-the-Loop</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Boutons Approuver/Rejeter pour les actions critiques.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Historique chiffré</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Conversations stockées localement (SQLite chiffré), purgées après 30 jours.</td>
    </tr>
  </tbody>
</table>

## Espace 2 — Supervision (Dashboard Agents)

Un tableau de bord en temps réel pour les administrateurs et le service qualité :

- **Vue des agents actifs** : État (idle, working, error), charge, dernière activité.
- **Graphiques de performance** : Latence moyenne, tokens consommés, taux de succès.
- **Journal d'audit live** : Flux scrollable des événements de sécurité.
- **Alertes** : Notifications push pour les anomalies (tentative de prompt injection, timeout, etc.).

## Espace 3 — Administration

Réservé aux rôles `ROLE_ADMIN` et `ROLE_RSSI` :

- **Gestion du SAS** : Activation/désactivation de l'anonymisation (avec justification obligatoire).
- **Configuration des agents** : Activation/désactivation, modification des budgets tokens.
- **Gestion des utilisateurs** : Synchronisation LDAP, attribution des rôles.
- **Paramètres système** : Modèle LLM actif, température, limites globales.

## Intégration avec la Gateway API

L'interface web n'est qu'un des clients de la Gateway API. L'application mobile dédiée au service qualité utilise les mêmes endpoints REST, garantissant une cohérence totale entre les interfaces.
