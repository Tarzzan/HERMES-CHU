<div align="center">
  <h1 style="color: #0052cc;">📊 APIs REST de Suivi Qualité</h1>
</div>

<br/>

Les APIs de suivi qualité constituent le pont entre le système agentique HERMES CHU et l'application mobile/web dédiée au service qualité. Elles exposent des données structurées permettant le suivi, l'audit et l'amélioration continue du système.

## Vue d'Ensemble des Groupes d'APIs

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #ec4899; color: white;">
      <th style="padding: 12px; text-align: left;">Groupe</th>
      <th style="padding: 12px; text-align: left;">Base Path</th>
      <th style="padding: 12px; text-align: left;">Description</th>
      <th style="padding: 12px; text-align: center;">Endpoints</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Anonymisation</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>/api/v1/privacy</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Statistiques et état du SAS d'anonymisation</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">5</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Audit</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>/api/v1/audit</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Journal d'audit et événements de sécurité</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">4</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Usage</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>/api/v1/usage</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Métriques d'utilisation du système</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">4</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Performance</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>/api/v1/performance</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Indicateurs de performance des agents</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">3</td>
    </tr>
  </tbody>
</table>

## Endpoints Détaillés

### Groupe Anonymisation (`/api/v1/privacy`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/status` | État actuel du SAS (activé/désactivé, version NER) |
| `GET` | `/stats` | Statistiques : entités détectées, taux de détection, faux positifs |
| `GET` | `/history` | Historique des activations/désactivations avec justifications |
| `POST` | `/toggle` | Activer/désactiver le SAS (nécessite `ROLE_ADMIN_PRIVACY`) |
| `GET` | `/entities/distribution` | Distribution des types d'entités détectées |

### Groupe Audit (`/api/v1/audit`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/events` | Liste paginée des événements d'audit (filtrable par type, date, agent) |
| `GET` | `/events/:id` | Détail d'un événement avec contexte complet |
| `GET` | `/alerts` | Alertes de sécurité actives (prompt injection, fuite détectée) |
| `GET` | `/compliance/report` | Rapport de conformité ISO 27001 généré automatiquement |

### Groupe Usage (`/api/v1/usage`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/sessions` | Sessions actives et historiques (par service, par utilisateur) |
| `GET` | `/tokens` | Consommation de tokens par période, par agent, par service |
| `GET` | `/agents/activity` | Activité des agents (requêtes traitées, taux de succès) |
| `GET` | `/trends` | Tendances d'utilisation sur 30/60/90 jours |

### Groupe Performance (`/api/v1/performance`)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/latency` | Latence moyenne par agent et par type de requête |
| `GET` | `/satisfaction` | Score de satisfaction utilisateur (feedback intégré) |
| `GET` | `/sla` | Respect des SLA définis (disponibilité, temps de réponse) |

## Authentification et Autorisation

Toutes les APIs sont protégées par :
1. **JWT Bearer Token** émis par Keycloak (durée de vie : 15 minutes)
2. **Scopes OAuth2** : `quality:read`, `quality:write`, `audit:read`
3. **Rate limiting** : 100 requêtes/minute par utilisateur

## Spécification OpenAPI

La spécification complète est disponible dans le fichier [`src/api-quality/openapi_qualite.yaml`](https://github.com/Tarzzan/PULSAR-CHU/blob/main/src/api-quality/openapi_qualite.yaml) et peut être visualisée via Swagger UI à l'adresse `/api/docs` une fois le système déployé.
