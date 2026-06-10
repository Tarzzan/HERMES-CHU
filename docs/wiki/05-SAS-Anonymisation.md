<div align="center">
  <h1 style="color: #0052cc;">🛡️ SAS d'Anonymisation (Privacy Engine)</h1>
</div>

<br/>

Le SAS d'anonymisation est le composant le plus critique du système HERMES CHU. Il garantit que **le modèle LLM ne traite jamais de données nominatives**. Ce principe est non-négociable et constitue la pierre angulaire de la conformité RGPD et du secret médical.

Le SAS fonctionne comme un proxy bidirectionnel transparent, intercalé entre l'interface utilisateur et l'orchestrateur Hermes.

## Pipeline d'Anonymisation en 5 Étapes

Le processus d'anonymisation se décompose en cinq étapes séquentielles, chacune traçable et auditable.

### Étape 1 — Détection des Entités (NER Clinique)

Un modèle NLP déterministe (non-génératif) spécialisé en données de santé françaises identifie les informations à caractère personnel. Le modèle utilisé est un **CamemBERT-bio** affiné sur des corpus médicaux français.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <thead>
    <tr style="background-color: #f8f9fa;">
      <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Type d'Entité</th>
      <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Exemples</th>
      <th style="padding: 10px; border: 1px solid #ddd; text-align: center;">Criticité</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;">Nom/Prénom</td>
      <td style="padding: 10px; border: 1px solid #ddd;">Jean Dupont, Dr. Martin</td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: center; color: #dc2626;"><strong>Critique</strong></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;">Date de naissance</td>
      <td style="padding: 10px; border: 1px solid #ddd;">15/03/1952</td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: center; color: #dc2626;"><strong>Critique</strong></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;">NIR (Sécurité sociale)</td>
      <td style="padding: 10px; border: 1px solid #ddd;">1 52 03 75 108 042 35</td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: center; color: #dc2626;"><strong>Critique</strong></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;">IPP (Identifiant Patient)</td>
      <td style="padding: 10px; border: 1px solid #ddd;">2024-CHU-00042</td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: center; color: #dc2626;"><strong>Critique</strong></td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd;">Adresse</td>
      <td style="padding: 10px; border: 1px solid #ddd;">12 rue de la Paix, Paris</td>
      <td style="padding: 10px; border: 1px solid #ddd; text-align: center; color: #ea580c;"><strong>Élevée</strong></td>
    </tr>
  </tbody>
</table>

### Étape 2 — Pseudonymisation Réversible

Chaque entité détectée est remplacée par un token unique et cohérent au sein de la session. La cohérence est essentielle : si "Jean Dupont" apparaît trois fois dans un prompt, il est remplacé trois fois par le même token `[PATIENT_A]`, permettant au LLM de maintenir la cohérence sémantique de son raisonnement.

### Étape 3 — Stockage Éphémère (Redis)

La table de mapping (token → donnée réelle) est stockée dans un cache Redis chiffré en mémoire vive, avec une durée de vie limitée à la session (TTL par défaut : 4 heures). À l'expiration, la table est détruite de manière sécurisée (overwrite + delete).

### Étape 4 — Réhydratation Contrôlée

Lorsque le LLM génère sa réponse contenant les tokens, le SAS effectue le remplacement inverse avant d'afficher le résultat à l'utilisateur. Cette opération n'est effectuée que si l'utilisateur dispose des habilitations nécessaires (vérification RBAC via Keycloak).

### Étape 5 — Journalisation

Chaque opération d'anonymisation/réhydratation est enregistrée dans le journal d'audit immuable : horodatage, identifiant de session, nombre d'entités traitées, types d'entités, et hash de vérification.

## Mode Activable/Désactivable Tracé

Le SAS d'anonymisation est **activé par défaut** pour tous les flux. Cependant, il peut être désactivé pour des cas d'usage spécifiques (ex: recherche sur données déjà anonymisées).

<table style="width: 100%; border-collapse: collapse;">
  <thead>
    <tr style="background-color: #f8f9fa;">
      <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">État du SAS</th>
      <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Qui peut modifier</th>
      <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Traçabilité</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd; color: #10b981;"><strong>Activé</strong> (défaut)</td>
      <td style="padding: 10px; border: 1px solid #ddd;">—</td>
      <td style="padding: 10px; border: 1px solid #ddd;">Automatique</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd; color: #dc2626;"><strong>Désactivé</strong></td>
      <td style="padding: 10px; border: 1px solid #ddd;"><code>ROLE_ADMIN_PRIVACY</code> uniquement</td>
      <td style="padding: 10px; border: 1px solid #ddd;">Justification obligatoire (min 20 car.) + log</td>
    </tr>
    <tr>
      <td style="padding: 10px; border: 1px solid #ddd; color: #f59e0b;"><strong>Mode Audit</strong></td>
      <td style="padding: 10px; border: 1px solid #ddd;"><code>ROLE_QUALITICIEN</code></td>
      <td style="padding: 10px; border: 1px solid #ddd;">Lecture seule des logs</td>
    </tr>
  </tbody>
</table>
