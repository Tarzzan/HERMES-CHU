# Guide de re-vendoring de `upstream/pulsar-agent`

> Établi à partir de la recette automatisée du 2026-06-11 (poste WIN10).
> Le vendoring actuel n'est complet qu'à **~25 %** : 3729 des 4961 fichiers de
> l'instantané upstream manquent (seuls 8 des 30 répertoires racine présents).
> Conséquence : le moteur ne tourne pas (dashboard web, desktop, gateway,
> install vérifiée par hash — tout est cassé). Ce guide explique comment
> recopier l'upstream **complet** en gardant la cohérence du rebranding.

## 1. Le bon instantané source

- **Dépôt :** `NousResearch/hermes-agent` (public).
- **Commit :** `acd7932c0` (`2026-06-10`) — le commit dont les modules sont
  **compatibles** avec les packages déjà vendorisés (vérifié : 110/111 symboles
  importés par le code existant sont présents ; le 111ᵉ est un import optionnel
  sous `try/except`).
- **⚠️ « 0.16.0 » n'est PAS une cible.** C'est la version figée en dur dans le
  `pyproject.toml` d'upstream (jamais incrémentée — `main` dit encore `0.16.0`).
  Les vraies versions sont des tags CalVer (`v2026.6.5`…). `v2026.6.5` (5 juin)
  est **trop ancien** : son `utils.py` n'a pas `model_forces_max_completion_tokens`,
  importé par `agent/auxiliary_client.py` → `ImportError`. Prendre le commit à la
  date du vendoring d'origine (~10 juin), d'où `acd7932c0`.

```bash
git clone --filter=blob:none https://github.com/NousResearch/hermes-agent.git
cd hermes-agent && git checkout acd7932c0
```

## 2. Périmètre à copier

Copier **l'arbre complet** (4961 fichiers, 30 répertoires racine), pas un
sous-ensemble. Le vendoring actuel n'a que : `agent/`, `gateway/`, `hermes_cli/`,
`optional-skills/`, `plugins/`, `scripts/`, `tools/`, `web/`.

Manquent notamment (bloquants) :
- **Build/runtime :** `package.json`, `package-lock.json`, `uv.lock`, `setup.py`,
  `MANIFEST.in`, `cli-config.yaml.example`, `.env.example`, le script `hermes`.
- **Packages :** `apps/` (desktop), `ui-tui/` (requis par le build web), `cron/`,
  `providers/`, `acp_adapter/`, `acp_registry/`, `tui_gateway/`, `optional-mcps/`,
  `skills/`, `locales/`, `assets/`, `tests/`, `docker/`, `nix/`.
- **14 modules top-level** (déjà ajoutés sur `main` mais à inclure dans ta copie) :
  `run_agent, model_tools, toolsets, batch_runner, trajectory_compressor,
  toolset_distributions, cli, hermes_bootstrap, hermes_constants, hermes_state,
  hermes_time, hermes_logging, utils, mcp_serve`.

Inclure `uv.lock` et `package-lock.json` : ils permettent l'install vérifiée par
hash (Python) et l'install reproductible du workspace npm.

## 3. Purge identité — frontière fonctionnel / branding

Règle d'or : **ne JAMAIS faire un `sed` global `hermes`→`pulsar`.** Dans le cœur
moteur, « hermes »/« nousresearch » est très majoritairement *fonctionnel*.

### À PRÉSERVER (fonctionnel — casse le moteur si modifié)
- Noms de modules / fichiers : `hermes_constants.py`, `hermes_cli/`, etc., et tous
  les `import` / `from hermes_* import`.
- Noms de fonctions / symboles : `get_hermes_home`, `get_default_hermes_root`,
  `display_hermes_home`, `set_hermes_home_override`, …
- Variables d'environnement : `HERMES_HOME` (lu par de nombreux modules) ; ton
  code mélange déjà `PULSAR_HOME` et `HERMES_HOME` — vérifier la cohérence.
- **`"nousresearch.com"`** dans `base_url_host_matches(url, "nousresearch.com")`
  (`run_agent.py`, `trajectory_compressor.py`) → détection du fournisseur d'API
  Nous. Le remplacer casse les appels LLM.
- Liens d'issues GitHub upstream dans les commentaires
  (`github.com/NousResearch/hermes-agent/issues/...`).
- Noms réels de modèles dans les messages factuels (« Nous Research Hermes 3 & 4 »).

### À REMPLACER (branding visible — sûr, chirurgical)
- Nom produit `"Hermes Agent"` → `"PULSAR CHU"`.
- Org en contexte d'affichage/footer : `"Nous Research"` / `"NousResearch"` →
  `"CHU de Guyane"` / `"Tarzzan"`.
- URLs about/footer → `https://github.com/Tarzzan/PULSAR-CHU`.

Réutiliser les remplacements **déjà encodés** dans `chu/branding/patch_pulsar.py`,
`patch_pulsar_full.py` et `Stage-ChuPatches` (install-chu.ps1) : ils sont ciblés
et éprouvés. La couche `chu/` (à la racine du dépôt) n'est pas concernée.

## 4. Déjà corrigé sur `main` (ne pas défaire)

- `installer/windows/install-chu.ps1` : séparation `$RepoRoot` (clone complet,
  git + `chu/`) et `$InstallDir` (= `upstream/pulsar-agent`, venv/deps/build/
  raccourcis). L'installeur attend donc le projet sous `upstream/pulsar-agent`.

## 5. Vérification après re-vendoring

1. Compat symboles (depuis la racine du dépôt) — doit afficher 0 manquant hors
   imports optionnels :
   ```bash
   # cf. le script ast de la recette (check imports top-level vs modules)
   ```
2. Recette automatisée via l'agent (banc déjà en place) : install complète →
   `import hermes_cli.main` → `hermes dashboard` (localhost:9119) →
   endpoints CHU (localhost:8001).
3. Cocher la checklist + exporter le PV.
