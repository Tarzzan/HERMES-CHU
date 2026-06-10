# Politique de Sécurité HERMES CHU (ISO 27001)

## 1. Objectif et Périmètre

Cette politique définit les règles de sécurité applicables au projet HERMES CHU, un système agentique hospitalier souverain. Le périmètre inclut l'orchestrateur, les agents spécialisés, le SAS d'anonymisation et les APIs de suivi qualité.

## 2. Signalement des Vulnérabilités

La sécurité de notre infrastructure hospitalière est notre priorité absolue. Si vous découvrez une vulnérabilité, nous vous prions de nous en informer immédiatement et de manière confidentielle.

### Versions Supportées

| Version | Support Sécurité | Description |
|---------|-----------------|-------------|
| `1.x.x` | ✅ Oui | Version de production actuelle |
| `< 1.0` | ❌ Non | Versions de développement / Alpha |

### Comment Signaler

Veuillez ne **PAS** créer d'Issue publique pour signaler une vulnérabilité de sécurité. 

Envoyez un e-mail détaillé à l'équipe RSSI (Responsable de la Sécurité des Systèmes d'Information) :
📧 **securite@chu-hermes.local** (adresse fictive pour l'exemple)

Votre e-mail doit inclure :
- Le type de vulnérabilité (ex: XSS, Prompt Injection, Fuite de données)
- Les étapes détaillées pour reproduire le problème
- Le composant affecté (ex: Privacy Engine, Interface Web)
- L'impact potentiel sur les données de santé (PHI)

### Temps de Réponse (SLA)

L'équipe sécurité s'engage à :
- Accuser réception de votre signalement sous **24 heures** ouvrées.
- Fournir une première évaluation de la criticité sous **48 heures**.
- Déployer un correctif pour les failles critiques sous **7 jours**.

## 3. Règles de Contribution Sécurisée

Toute contribution au code source de HERMES CHU doit respecter les règles suivantes :

1. **Aucune donnée réelle** : Les tests unitaires et d'intégration ne doivent utiliser que des données synthétiques (mock data). L'utilisation de vraies données patients (PHI) est strictement interdite.
2. **Revue de code obligatoire** : Toute Pull Request (PR) nécessite l'approbation d'au moins deux développeurs seniors et une validation automatique de la CI/CD (SAST/DAST).
3. **Scan des dépendances** : Les nouvelles dépendances doivent être scannées (ex: Trivy) pour s'assurer qu'elles ne comportent aucune vulnérabilité connue (CVE).
4. **Gestion des secrets** : Les clés API, mots de passe et tokens ne doivent jamais être committés. Utilisez des variables d'environnement ou un gestionnaire de secrets (ex: HashiCorp Vault).

## 4. Garde-Fous (Guardrails)

Conformément à l'architecture HERMES CHU, toute modification des composants suivants nécessite une revue approfondie par le RSSI :
- **Privacy Engine** (SAS d'anonymisation)
- **Tool Registry** (Fonctions autorisées pour les agents)
- **System Prompts** des agents
- **Configuration Keycloak** (RBAC)

---
*Dernière mise à jour : Juin 2026*
*Propriétaire : Équipe RSSI HERMES CHU*
