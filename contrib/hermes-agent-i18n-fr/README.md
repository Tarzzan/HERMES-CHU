# Contribution — Traduction française (fr) du desktop Hermes Agent

`fr.ts` est une **traduction française complète** de l'interface
`apps/desktop` (≈1450 chaînes), prête à être proposée au projet d'origine
**hermes-agent** (Nous Research).

## Propre pour l'upstream
- **Marque d'origine** conservée : « Hermes » (aucune référence « PULSAR »).
- **Aucune fonction tierce** : ni Privacy Engine, ni RGPD/ISO 27001, ni
  identité CHU — uniquement les libellés standard de l'UI, traduits.
- **Convention upstream** : `defineLocale({...})` (deep-merge sur `en`),
  comme `ja.ts` / `zh.ts`.
- Termes techniques/marques conservés (Telegram, Slack, MCP, YOLO, cron,
  gateway, commandes CLI).

## Intégration (PR vers hermes-agent)
1. Copier `fr.ts` dans `apps/desktop/src/i18n/`.
2. `types.ts` : ajouter `'fr'` au type `Locale`.
3. `catalog.ts` : `import { fr } from './fr'` + ajouter `fr` à `TRANSLATIONS`.
4. `languages.ts` : ajouter l'option `{ id: 'fr', name: 'Français',
   englishName: 'French', configValue: 'fr' }` + alias `fr/fr-fr`.

Auteur de la traduction : William MERI.
