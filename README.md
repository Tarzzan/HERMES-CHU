<div align="center">

# ☤ HERMES CHU

### Système Agentique Hospitalier Souverain

<br/>

<img src="docs/architecture/architecture_diagram.png" alt="Architecture HERMES CHU" width="800"/>

<br/>

[![ISO 27001](https://img.shields.io/badge/Conformité-ISO_27001-blue?style=for-the-badge&logo=shield)](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/06-Conformite-ISO-27001.md)
[![HDS](https://img.shields.io/badge/Certification-HDS-green?style=for-the-badge&logo=hospital)](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/05-SAS-Anonymisation.md)
[![Hermes](https://img.shields.io/badge/Basé_sur-Hermes_Agent-purple?style=for-the-badge&logo=github)](https://github.com/NousResearch/hermes-agent)
[![License](https://img.shields.io/badge/Licence-Propriétaire_CHU-red?style=for-the-badge)](LICENSE)

---

**Orchestration multi-agents IA pour Centre Hospitalier Universitaire**  
*Anonymisation traçable • Garde-fous médicaux • Interface de pilotage • APIs Qualité*

[📖 Wiki Complet](https://github.com/Tarzzan/HERMES-CHU/wiki) · [🗺️ Roadmap](https://github.com/Tarzzan/HERMES-CHU/milestones) · [📋 Issues](https://github.com/Tarzzan/HERMES-CHU/issues)

</div>

---

## 🎯 Vision

**HERMES CHU** est le système nerveux numérique d'un Centre Hospitalier Universitaire. Il ne s'agit pas d'un chatbot, mais d'un **orchestrateur multi-agents autonome** capable de décomposer des tâches complexes, de déléguer à des agents spécialisés, et de s'auto-améliorer — le tout dans un cadre de sécurité et de conformité réglementaire maximal.

Le système repose sur le framework open-source [Hermes Agent](https://github.com/NousResearch/hermes-agent) de NousResearch (189k+ ⭐), adapté aux exigences du secteur hospitalier français.

---

## 🏗️ Architecture en 5 Couches

```
┌─────────────────────────────────────────────────────────────────────┐
│  COUCHE 1 — PRÉSENTATION                                            │
│  Interface Web Orchestrateur │ App Qualité │ API Gateway SIH        │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 2 — SÉCURITÉ & CONFORMITÉ (ISO 27001 / HDS)                │
│  SAS Anonymisation │ Garde-Fous 4 niveaux │ RBAC/MFA │ Audit       │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 3 — ORCHESTRATION (Hermes Core Modifié)                     │
│  Agent Pilote │ State Machine │ Function Calling │ Mémoire          │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 4 — AGENTS SPÉCIALISÉS (Conteneurisés)                      │
│  Clinique │ Administratif │ Logistique │ Recherche │ Qualité        │
├─────────────────────────────────────────────────────────────────────┤
│  COUCHE 5 — SYSTÈMES HOSPITALIERS                                    │
│  DPI (FHIR) │ GAM │ SIL │ PACS │ LDAP/AD                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Principes Non-Négociables

| Principe | Description |
| :--- | :--- |
| **Souveraineté totale** | Aucune donnée ne quitte l'infrastructure HDS. LLM hébergé localement. |
| **Transparence** | Chaque décision de l'agent est traçable et auditable. |
| **Humain dans la boucle** | Toute action critique nécessite une validation explicite. |
| **Anonymisation par défaut** | Le LLM ne traite jamais de données nominatives. |
| **Francisation complète** | Interface, prompts, documentation — tout en français. |

---

## 📁 Structure du Projet

```
HERMES-CHU/
├── src/
│   ├── orchestrator/       # Agent Pilote (Hermes modifié)
│   ├── privacy-engine/     # SAS d'Anonymisation (NER + Pseudonymisation)
│   ├── agents/             # Sous-agents spécialisés
│   ├── web-ui/             # Interface Web de Pilotage (React/TS)
│   └── api-quality/        # APIs de Suivi Qualité (FastAPI)
├── infrastructure/
│   ├── kubernetes/         # Manifestes K8s
│   └── docker/             # Dockerfiles
├── docs/
│   ├── architecture/       # Diagrammes et schémas
│   └── wiki/               # Sources du wiki
└── .github/
    ├── ISSUE_TEMPLATE/     # Templates d'issues
    └── workflows/          # CI/CD
```

---

## 🗺️ Roadmap

| Phase | Durée | Objectif |
| :--- | :--- | :--- |
| **Phase 1 — Fondations** | Mois 1-3 | Infrastructure, LLM local, orchestrateur de base |
| **Phase 2 — Sécurité** | Mois 4-6 | SAS anonymisation, garde-fous, audit ISO 27001 |
| **Phase 3 — Agents** | Mois 7-9 | Sous-agents spécialisés, function calling, intégration SIH |
| **Phase 4 — Interface** | Mois 10-12 | Interface web, APIs qualité, dashboard |
| **Phase 5 — Pilote** | Mois 13-15 | Déploiement 2 services, tests utilisateurs |
| **Phase 6 — Production** | Mois 16+ | Extension multi-services, certification, amélioration continue |

➡️ [Voir la roadmap détaillée (Milestones)](https://github.com/Tarzzan/HERMES-CHU/milestones)

---

## 📖 Documentation

La documentation complète est disponible dans le [Wiki](https://github.com/Tarzzan/HERMES-CHU/wiki) :

1. [Accueil & Vision](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/01-Accueil.md)
2. [Architecture Technique](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/02-Architecture-Technique.md)
3. [Cœur Agentique Hermes](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/03-Coeur-Agentique.md)
4. [Réseau d'Agents Spécialisés](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/04-Agents-Specialises.md)
5. [SAS d'Anonymisation](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/05-SAS-Anonymisation.md)
6. [Conformité ISO 27001](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/06-Conformite-ISO-27001.md)
7. [Garde-Fous & Sécurité](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/07-Garde-Fous.md)
8. [Interface Web de Pilotage](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/08-Interface-Web.md)
9. [APIs Suivi Qualité](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/09-APIs-Qualite.md)
10. [Déploiement & Infrastructure](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/10-Deploiement.md)
11. [Roadmap Détaillée](https://github.com/Tarzzan/HERMES-CHU/blob/main/docs/wiki/11-Roadmap.md)

---

## ⚡ Démarrage Rapide (Développement)

```bash
# Cloner le dépôt
git clone https://github.com/Tarzzan/HERMES-CHU.git
cd HERMES-CHU

# Lancer l'environnement de développement
docker compose -f infrastructure/docker/docker-compose.dev.yml up -d

# Accéder à l'interface web
open http://localhost:3000
```

---

## 🤝 Contribution

Ce projet est développé en interne pour le CHU. Les contributions sont gérées via les [Issues](https://github.com/Tarzzan/HERMES-CHU/issues) et les Pull Requests avec revue obligatoire.

---

<div align="center">

*Projet HERMES CHU — Système Agentique Hospitalier Souverain*  
*Basé sur [Hermes Agent](https://github.com/NousResearch/hermes-agent) par [NousResearch](https://nousresearch.com)*

</div>
