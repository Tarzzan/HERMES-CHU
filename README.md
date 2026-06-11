<div align="center">

# PULSAR

### Plateforme Unifiée de Liaison, de Surveillance et d'Assistance en temps Réel

**Système Agentique Médical — DSIO CHU de Guyane**

*Chaque impulsion active l'intelligence*

---

[![Version](https://img.shields.io/badge/version-2.3.0-0077a8?style=flat-square)](https://github.com/Tarzzan/PULSAR-CHU/releases)
[![Conformité](https://img.shields.io/badge/conformité-RGPD%20%7C%20HDS%20%7C%20ISO%2027001-00897b?style=flat-square)](#conformite)
[![Licence](https://img.shields.io/badge/licence-Apache%202.0-42A5F5?style=flat-square)](LICENSE)
[![Auteur](https://img.shields.io/badge/auteur-William%20MERI%20%7C%20DSIO%20CHU%20de%20Guyane-1565C0?style=flat-square)](https://github.com/Tarzzan)

[Documentation](https://github.com/Tarzzan/PULSAR-CHU/wiki) · [Releases](https://github.com/Tarzzan/PULSAR-CHU/releases) · [Roadmap](https://github.com/Tarzzan/PULSAR-CHU/milestones) · [Issues](https://github.com/Tarzzan/PULSAR-CHU/issues)

> **Dépôt :** `https://github.com/Tarzzan/PULSAR-CHU.git`  
> **Mise à jour locale :** double-cliquer sur `installer/windows/scripts/Pulsar-Apply.bat`

</div>

---

## Vision

**PULSAR** est une plateforme agentique médicale développée par la **Direction des Systèmes d'Information et de l'Organisation (DSIO) du CHU de Guyane**. Elle orchestre des agents IA spécialisés pour assister les professionnels de santé dans leurs missions cliniques, administratives, logistiques et qualité — dans le strict respect du secret médical, du RGPD et des exigences HDS.

PULSAR est un **produit à part entière**, conçu pour et par le milieu hospitalier. Son moteur agentique est un **fork maintenu** de [hermes-agent (NousResearch)](https://github.com/NousResearch/hermes-agent), rebaptisé `pulsar-agent` dans `upstream/`. Les modifications du fork se limitent au rebranding (identité PULSAR) ; toute la logique hospitalière (Privacy Engine, agents, garde-fous) est isolée dans la couche `chu/`, greffée via middleware et skills natifs.

> **Principe fondateur :** Une pulsation régulière réveille des agents vigilants. PULSAR émet l'impulsion — les agents répondent.

> **Pour le POC :** le Privacy Engine RGPD anonymise les données PHI avant tout envoi, ce qui permet d'utiliser Azure OpenAI ou OpenAI en toute conformité RGPD, sans attendre l'infrastructure vLLM on-premise de production.

---

## Architecture en 5 Couches

```
+---------------------------------------------------------------------+
|  COUCHE 1 -- PRESENTATION                                           |
|  PULSAR Dashboard (Web)  |  PULSAR Desktop (Electron)  |  API SIH  |
+---------------------------------------------------------------------+
|  COUCHE 2 -- SECURITE & CONFORMITE (RGPD / HDS / ISO 27001)        |
|  SAS Anonymisation  |  Garde-Fous 4 niveaux  |  RBAC/MFA  |  Audit |
+---------------------------------------------------------------------+
|  COUCHE 3 -- ORCHESTRATION (Moteur Agentique)                       |
|  Agent Pilote  |  State Machine  |  Function Calling  |  Memoire    |
+---------------------------------------------------------------------+
|  COUCHE 4 -- AGENTS SPECIALISES (Conteneurises)                     |
|  Clinique  |  Administratif  |  Logistique  |  Recherche  |  Qualite|
+---------------------------------------------------------------------+
|  COUCHE 5 -- SYSTEMES HOSPITALIERS                                  |
|  DPI (FHIR R4)  |  GAM  |  SIL  |  PACS  |  LDAP/AD               |
+---------------------------------------------------------------------+
```

---

## Principes Non-Négociables

| Principe | Description |
|----------|-------------|
| **Souveraineté totale** | Aucune donnée ne quitte l'infrastructure HDS. LLM hébergeable localement (vLLM/Ollama). |
| **Anonymisation par défaut** | Le LLM ne traite jamais de données nominatives. Privacy Engine toujours actif. |
| **Humain dans la boucle** | Toute action critique nécessite une validation explicite du professionnel de santé. |
| **Transparence** | Chaque décision de l'agent est traçable, auditable et explicable. |
| **Francisation complète** | Interface, prompts, documentation, messages d'erreur — tout en français. |
| **Séparation des couches** | La logique métier upstream (`upstream/pulsar-agent`) n'est jamais modifiée — seul le rebranding y est appliqué. Toute la couche hospitalière est isolée dans `chu/`. |

---

## Fonctionnalités

### Agents Spécialisés CHU

| Agent | Rôle | Outils |
|-------|------|--------|
| **Agent Clinique** | Synthèse DPI, aide diagnostique, comptes-rendus | FHIR R4, PubMed, Thériaque, CIM-10 |
| **Agent Administratif** | Admissions, courriers, facturation, ALD | GAM, FHIR R4 admin, MSSanté |
| **Agent Logistique** | Stocks, équipements biomédicaux, flux | ERP hospitalier, GMAO |
| **Agent Recherche** | Veille bibliographique, protocoles, essais | PubMed, ClinicalTrials, HAS |
| **Agent Qualité** | EIG, certification HAS, ISO 27001, IPAQSS | API Qualité PULSAR, métriques |

### Privacy Engine RGPD

Le composant le plus critique de PULSAR. Il garantit que **le LLM ne traite jamais de données nominatives**.

| Étape | Mécanisme |
|-------|-----------|
| Détection NER | CamemBERT-bio affiné sur corpus médicaux français |
| Anonymisation | Remplacement par tokens pseudonymes réversibles |
| Transmission | Uniquement les tokens anonymisés sont envoyés au LLM |
| Restitution | Ré-identification locale avant affichage |
| Audit | Chaque opération tracée dans le journal immuable |

**Mode Glass-Break :** accès exceptionnel aux données nominatives avec justification obligatoire, traçabilité complète et expiration automatique.

### Conformité Réglementaire

| Référentiel | Implémentation |
|-------------|----------------|
| **RGPD** | Anonymisation par défaut, consentement, droit à l'oubli, DPO notifié |
| **HDS** | Infrastructure souveraine, journaux 10 ans, chiffrement AES-256-GCM |
| **ISO 27001** | RBAC 5 rôles, MFA obligatoire, TLS 1.3, audit trail PostgreSQL |
| **Secret médical** | Aucune donnée nominative hors périmètre HDS |
| **HAS** | Traçabilité des décisions, validation humaine obligatoire |

### Rétention des Données

| Type de donnée | Durée | Traitement à expiration |
|----------------|-------|------------------------|
| Conversations | 90 jours | Anonymisation |
| Journaux d'audit | 10 ans | Archivage chiffré |
| Mémoire persistante | 1 an | Revue annuelle |
| Trajectoires fine-tuning | 2 ans | Anonymisation complète |

### Interfaces et Thèmes

| Interface | Commande | Description |
|-----------|----------|-------------|
| **PULSAR Dashboard** | `pulsar dashboard` | Interface web navigateur — port 9119 |
| **PULSAR Desktop** | `pulsar desktop` | Application native Electron — fenêtre autonome |
| **PULSAR CLI** | `pulsar chat` | Interface ligne de commande |

| Thème | Usage | Ambiance |
|-------|-------|----------|
| **PULSAR** (nuit) | Sessions intensives, centre de commande | Bleu nuit + cyan électrique |
| **PULSAR Light** (jour) | Présentations, réunions, démonstrations | Blanc médical + teal |

---

## Installation Rapide (Windows)

Téléchargez et lancez **[PULSAR-Setup-2.3.0.exe](https://github.com/Tarzzan/PULSAR-CHU/releases/latest)** — aucun droit administrateur requis.

```cmd
pulsar dashboard     # Interface web (recommande)
pulsar desktop       # Application native Electron
pulsar setup         # Reconfigurer le provider LLM
pulsar update        # Mettre a jour
pulsar --help        # Aide complete
```

---

## Structure du Dépôt

```
PULSAR-CHU/
+-- upstream/                          <- Moteur agentique (NousResearch, INCHANGE)
|   +-- hermes-agent/                  # hermes-agent v0.16.0
+-- chu/                               <- Couche PULSAR
|   +-- privacy_engine/                # SAS d'anonymisation RGPD
|   +-- skills/                        # 5 agents specialises CHU
|   +-- branding/                      # Identite visuelle PULSAR (2 themes)
|   +-- api/                           # API CHU FastAPI (port 8001)
|   +-- config_chu.yaml                # Configuration PULSAR complete
|   +-- web-extensions/                # Extensions interface web React
+-- chu-desktop/                       # Couche desktop Electron
|   +-- src/app/privacy/               # Panneau Privacy Engine (React)
|   +-- src/app/agents/                # Page Agents CHU (React)
|   +-- electron/                      # IPC securise + preload
|   +-- Patch-PULSAR-Electron.bat      # Patch identite avant build
+-- installer/                         # Installateurs Windows (NSIS)
+-- docs/                              # Documentation (wiki 10 chapitres + securite)
```

---

## Roadmap

| Phase | Durée | Objectif |
|-------|-------|----------|
| **Phase 1 — Fondations** | Mois 1-3 | Infrastructure, LLM local, orchestrateur de base |
| **Phase 2 — Sécurité** | Mois 4-6 | SAS anonymisation, garde-fous, audit ISO 27001 |
| **Phase 3 — Agents** | Mois 7-9 | Sous-agents spécialisés, function calling, intégration SIH |
| **Phase 4 — Interface** | Mois 10-12 | Interface web PULSAR, APIs qualité, dashboard |
| **Phase 5 — Pilote** | Mois 13-15 | Déploiement 2 services, tests utilisateurs |
| **Phase 6 — Production** | Mois 16+ | Extension multi-services, certification, amélioration continue |

---

## Documentation

1. [Accueil & Vision](docs/wiki/01-Accueil.md)
2. [Architecture Technique](docs/wiki/02-Architecture-Technique.md)
3. [Coeur Agentique](docs/wiki/03-Coeur-Agentique.md)
4. [Agents Spécialisés](docs/wiki/04-Agents-Specialises.md)
5. [SAS d'Anonymisation](docs/wiki/05-SAS-Anonymisation.md)
6. [Conformité ISO 27001](docs/wiki/06-Conformite-ISO-27001.md)
7. [Garde-Fous & Sécurité](docs/wiki/07-Garde-Fous.md)
8. [Interface Web PULSAR](docs/wiki/08-Interface-Web.md)
9. [APIs Suivi Qualité](docs/wiki/09-APIs-Qualite.md)
10. [Déploiement & Infrastructure](docs/wiki/10-Deploiement.md)

---

## Auteur et Crédits

**William MERI** — Ingénieur Principal IA & Systèmes d'Information
Direction des Systèmes d'Information et de l'Organisation (DSIO) — CHU de Guyane

GitHub : [github.com/Tarzzan](https://github.com/Tarzzan)

**Moteur agentique :** hermes-agent (NousResearch) — Apache 2.0 — intégré dans `upstream/`

---

## Licence

Apache License 2.0 — voir [LICENSE](LICENSE)

La couche PULSAR (`chu/`, `chu-desktop/`, `installer/`, `docs/`) est développée et maintenue par William MERI / DSIO CHU de Guyane.
Le moteur agentique (`upstream/hermes-agent/`) est la propriété de NousResearch, distribué sous Apache 2.0.

---

<div align="center">

*PULSAR — Système Agentique Médical — DSIO CHU de Guyane*

*PULSAR CHU v2.3.0 — DSIO CHU de Guyane — William MERI*

</div>
