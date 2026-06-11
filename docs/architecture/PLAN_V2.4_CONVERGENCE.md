# PULSAR v2.4 « Convergence » — Plan de consolidation technique

> **Statut :** proposition — DSIO CHU de Guyane
> **Pré-requis :** correctifs v2.3.1 appliqués (scanner_phi, endpoints métriques,
> imports orchestrateur, bridge IPC desktop, Dockerfiles manquants, CI GitHub Actions).
> **Complément de :** `docs/wiki/11-Roadmap.md` (phases de déploiement hospitalier).
> Ce plan traite la dette d'architecture interne, pas le calendrier de déploiement.

---

## Le problème structurel : deux générations de code cohabitent

Le dépôt contient aujourd'hui **deux piles parallèles** nées de deux phases du projet :

| | Pile `src/` (architecture cible) | Pile `chu/` (greffe sur pulsar-agent) |
|---|---|---|
| Privacy Engine | `src/privacy-engine/anonymizer.py` — **async**, NER CamemBERT-bio, stockage Redis/mémoire | `chu/privacy_engine/middleware.py` — **sync**, regex seul, audit chaîné SHA-256, glass-break |
| API | `src/orchestrator/serveur.py` (port 8000, chat SSE/WS) | `chu/api/serveur_chu.py` (port 8001, config/privacy/audit/métriques) |
| Agents | `src/agents/*.py` (Python + connecteur FHIR) | `chu/skills/*.md` (skills prompt-based) |
| Tests | `tests/` ciblent **uniquement** la pile `src/` | aucun test dédié |
| Déploiement | docker-compose dev/prod + K8s (partiel) | Dockerfile.pulsar VPS (moteur pulsar-agent) |

Chaque pile a ce que l'autre n'a pas. C'est la source principale d'incohérence du projet —
et l'opportunité principale de la v2.4 : **converger vers un seul moteur**.

---

## Chantier 1 — Un seul Privacy Engine (`pulsar_privacy`)

Fusionner les deux implémentations en un paquet unique installable :

```
pulsar_privacy/
├── moteur.py          # API async unique : anonymiser(), scanner_phi(), controle_sortie()
├── backends/
│   ├── regex.py       # backend POC actuel (chu/) — zéro dépendance ML
│   ├── camembert.py   # backend NER production (src/) — almanach/camembert-bio-medical
│   └── hybride.py     # NER + filet regex (recommandé en production)
├── stockage.py        # TableCorrespondance : mémoire (POC) / Redis TTL+AES (prod)
├── audit.py           # JournalAudit chaîné SHA-256 (depuis chu/) + export PostgreSQL
└── glass_break.py     # mode urgence avec justification + expiration (depuis chu/)
```

Principes :
- **API async** (la version sync devient un wrapper `asyncio.run` pour patch_hermes.py).
- Le **backend se choisit par config** (`backend_ner: regex | camembert_bio | hybride`) —
  la clé existe déjà dans `config_chu.yaml:119`, elle devient enfin effective.
- `chu/privacy_engine/` et `src/privacy-engine/` deviennent de simples ré-exports
  pendant une version (rétro-compatibilité), puis sont supprimés en v2.5.
- Les tests de `tests/privacy-engine/` couvrent les **deux backends** via paramétrage pytest.

**Critère de réussite :** taux de rappel PHI ≥ 95 % sur un corpus synthétique français
de 500 phrases cliniques (à générer — chantier 1b), contre ~70 % estimé en regex seul
sur les noms de patients en texte libre.

## Chantier 2 — Topologie de services unique et documentée

Une seule carte des ports, appliquée partout (compose, K8s, .env, docs, skills) :

| Port | Service | Source |
|------|---------|--------|
| 3000 | Web UI React (dev) | `src/web-ui` |
| 8000 | Orchestrateur (chat, SSE, WS) | `src/orchestrator` |
| 8001 | API CHU (privacy, config, audit, métriques) | `chu/api` |
| 8002 | API Qualité (incidents, rapports, métriques agents) | `src/api-quality` |
| 9119 | Dashboard PULSAR (moteur upstream) | `upstream/pulsar-agent` |

- Plus **aucune URL en dur** : `CHU_API_BASE`, `VITE_CHU_API_BASE`,
  `ORCHESTRATEUR_URL` partout (le desktop est déjà migré en v2.3.1).
- Publier cette table dans `docs/wiki/02-Architecture-Technique.md` et le README.

## Chantier 3 — Boucle qualité fermée (l'Agent Qualité devient utile)

La v2.3.1 a livré `/api/chu/metriques`, `/api/chu/anonymisation/stats` et `/api/chu/insights`.
La v2.4 ferme la boucle :

1. **Pont 8001 → 8002** : un job (cron pulsar-agent) pousse chaque nuit les insights
   CHU vers l'API Qualité (`POST /api/v1/metriques`), qui les persiste en PostgreSQL.
2. **Rapport hebdomadaire automatique** : l'Agent Qualité génère chaque lundi un
   rapport (PHI résiduels, glass-breaks, taux d'anonymisation, incidents) déposé
   dans la GED et notifié au RSSI — premier agent PULSAR réellement autonome,
   sur un périmètre sans risque patient.
3. **Seuils d'alerte** : PHI résiduel en sortie LLM > 0 sur 24 h → alerte immédiate
   (l'événement `phi_residuel_sortie_llm` est déjà journalisé depuis v2.3.1).

## Chantier 4 — Déploiement complet et reproductible

- **K8s** : compléter `infrastructure/kubernetes/` (manifests vllm, privacy-engine,
  api-qualite, web-ui + NetworkPolicies associées — aujourd'hui seules celles de
  l'orchestrateur existent alors que sa NetworkPolicy y fait référence).
- **CI/CD** : étendre `.github/workflows/ci.yml` (v2.3.1) avec build des 4 images
  Docker + scan Trivy (le script `deploy-staging.sh` le fait déjà à la main) +
  release NSIS automatisée sur tag `v*`.
- **Un seul chemin d'installation par cible** : poste Windows (NSIS), VPS POC
  (compose pulsar), datacenter HDS (K8s). Le README pointe vers les trois.

## Chantier 5 — Durcissement glass-break (RGPD/RSSI)

- Approbation à **deux personnes** pour le glass-break hors urgence vitale
  (demandeur + validateur avec rôle `ROLE_RSSI` ou cadre de garde).
- Notification temps réel au RSSI à chaque activation (webhook + e-mail).
- Rapport mensuel automatique des glass-breaks (généré par l'Agent Qualité, chantier 3).

---

## Séquencement proposé

| Sprint | Livrable | Risque principal |
|--------|----------|------------------|
| S1-S2 | Chantier 2 (topologie) + corpus synthétique PHI (1b) | faible |
| S3-S6 | Chantier 1 (pulsar_privacy + backend CamemBERT) | VRAM/CPU du NER en prod |
| S5-S6 | Chantier 3 (boucle qualité) — parallélisable | faible |
| S7-S8 | Chantier 4 (K8s + CI/CD complets) | accès cluster HDS |
| S8 | Chantier 5 (glass-break durci) | arbitrage métier urgences |

**Définition de fini v2.4 :** un développeur qui clone le dépôt lance la pile complète
avec une commande par cible, la CI est verte, un seul Privacy Engine existe, et
l'Agent Qualité produit son premier rapport hebdomadaire sans intervention humaine.
