# Contribuer à HERMES CHU

Merci de l'intérêt que vous portez à HERMES CHU ! En tant que système agentique manipulant des données de santé, nous appliquons des règles strictes pour garantir la sécurité, la souveraineté et la conformité ISO 27001 / HDS.

## Code de Conduite

Ce projet est développé en interne pour les besoins du CHU. Les contributeurs doivent faire preuve de professionnalisme, de respect et d'une rigueur absolue concernant le traitement des données médicales.

## Processus de Contribution

### 1. Signaler un Bug ou Proposer une Fonctionnalité

- Utilisez les **Issues** GitHub.
- Choisissez le bon label (ex: `bug`, `enhancement`, `securite`).
- Fournissez autant de détails que possible (logs, étapes de reproduction, contexte).
- **ATTENTION : Ne postez JAMAIS de vraies données médicales (PHI) dans les issues.**

### 2. Environnement de Développement

1. Clonez le dépôt : `git clone https://github.com/Tarzzan/PULSAR-CHU.git`
2. Installez les dépendances locales (Python 3.12, Node.js 20+).
3. Lancez l'environnement de développement via Docker : `docker compose -f infrastructure/docker/docker-compose.dev.yml up -d`

### 3. Règles de Développement

- **Langue** : Le code (noms de variables, fonctions) peut être en anglais pour s'aligner sur les standards de développement, mais les **commentaires**, les **logs** et la **documentation** doivent être en **français**.
- **Tests** : Toute nouvelle fonctionnalité doit être accompagnée de tests unitaires. La couverture de code doit rester > 80%.
- **Anonymisation** : Si vous touchez au flux de données, assurez-vous que les données passent systématiquement par le `PrivacyEngine`.

### 4. Soumettre une Pull Request (PR)

1. Créez une branche depuis `main` avec un nom explicite (ex: `feat/agent-clinique-synthese` ou `fix/sas-anonymisation`).
2. Rédigez un message de commit clair et descriptif.
3. Ouvrez la PR vers `main`.
4. Liez la PR à l'Issue correspondante (ex: `Closes #42`).
5. La PR doit passer avec succès les pipelines CI/CD (Linting, Tests, SAST).
6. Attendez la revue de code par au moins un mainteneur (deux pour les composants critiques de sécurité).

## Architecture et Documentation

Avant de contribuer, veuillez lire attentivement la documentation dans le [Wiki](https://github.com/Tarzzan/PULSAR-CHU/wiki) (ou dans `docs/wiki/`), en particulier :
- L'Architecture Technique
- Le SAS d'Anonymisation
- Le Système de Garde-Fous

Merci pour votre contribution à la modernisation de notre système hospitalier !
