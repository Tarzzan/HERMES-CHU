<div align="center">
  <h1 style="color: #0052cc;">🏗️ Architecture Technique Globale</h1>
</div>

<br/>

L'architecture HERMES CHU s'organise en cinq couches distinctes, chacune isolée par des frontières de sécurité explicites pour répondre aux exigences de la certification HDS et de la norme ISO 27001.

## 1. Vue d'Ensemble des Couches

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #0052cc; color: white;">
      <th style="padding: 12px; text-align: left;">Couche</th>
      <th style="padding: 12px; text-align: left;">Composants</th>
      <th style="padding: 12px; text-align: left;">Rôle</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>1. Présentation</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Interface Web (React), App Qualité, API Gateway</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Interaction utilisateur et exposition des services vers l'extérieur du cluster.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>2. Sécurité</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">SAS Anonymisation, Garde-fous, Keycloak (RBAC), Audit Log</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Filtrage, authentification et journalisation de tous les flux entrants/sortants.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>3. Orchestration</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Agent Pilote (Hermes Core), Mémoire SQLite, Tool Registry</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Décomposition des tâches, maintien de l'état et routage vers les sous-agents.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>4. Agents Spécialisés</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Agent Clinique, Administratif, Logistique, Recherche</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Exécution des tâches métier spécifiques dans des conteneurs isolés.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>5. SIH</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">DPI (FHIR), GAM, LDAP/AD</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Système d'Information Hospitalier existant (source de vérité).</td>
    </tr>
  </tbody>
</table>

## 2. Diagramme de Flux

L'image ci-dessous illustre comment une requête utilisateur traverse les différentes couches de sécurité avant d'atteindre le cœur agentique.

<img src="https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/docs/architecture/architecture_diagram.png" alt="Diagramme d'Architecture" width="100%" />

## 3. Choix Technologiques Clés

Le système repose sur une stack moderne, souveraine et open-source :

* **Modèle IA** : `Hermes-3-Llama-3.1-70B-Instruct` (quantisation AWQ 4-bit)
* **Serveur d'inférence** : vLLM (haute performance, compatible OpenAI API)
* **Orchestration** : Kubernetes (K3s ou RKE2 pour la conformité)
* **Backend** : Python 3.12 (FastAPI pour les APIs, asyncio pour l'orchestrateur)
* **Frontend** : React 18 + TypeScript + TailwindCSS
* **Bases de données** :
  * PostgreSQL (Journal d'audit immuable)
  * Redis Cluster (Table de mapping d'anonymisation éphémère)
  * SQLite FTS5 chiffré (Mémoire de session et recherche sémantique)

Pour plus de détails sur le déploiement de ces composants, consultez la page [Déploiement & Infrastructure](10-Deploiement).
