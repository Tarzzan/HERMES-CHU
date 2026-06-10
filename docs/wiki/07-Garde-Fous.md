<div align="center">
  <h1 style="color: #0052cc;">🚧 Système de Garde-Fous à 4 Niveaux</h1>
</div>

<br/>

Le système de garde-fous (Guardrails) opère à quatre niveaux distincts pour garantir la sécurité et la fiabilité des actions de l'agent.

<img src="https://raw.githubusercontent.com/Tarzzan/HERMES-CHU/main/docs/architecture/guardrails_diagram.png" alt="Diagramme des Garde-Fous" width="100%" />

## Niveau 1 — Filtrage des Entrées (Input Guardrails)

Avant même d'atteindre le SAS d'anonymisation, chaque requête utilisateur est analysée :
- **Prompt injection** : Détection des tentatives de contournement (ex: "Ignore tes instructions précédentes").
- **Diagnostic médical** : Blocage des demandes de diagnostic direct (l'agent n'est pas un dispositif médical certifié).
- **Périmètre** : Vérification que la requête correspond aux droits de l'utilisateur.

## Niveau 2 — Validation des Appels d'Outils (Tool Call Guardrails)

Lorsqu'un agent génère un appel de fonction (*function call*) :
- **Whitelist RBAC** : Vérification que l'outil est autorisé pour le rôle de l'utilisateur.
- **Validation des paramètres** : Double vérification de l'absence de PHI non-anonymisés.
- **Human-in-the-Loop** : Pour les outils à impact élevé (ex: écriture DPI), déclenchement d'une demande d'approbation explicite dans l'interface.

## Niveau 3 — Filtrage des Sorties (Output Guardrails)

La réponse générée par le LLM est analysée avant affichage :
- **Contenu dangereux** : Détection de recommandations médicales non encadrées.
- **Fuite SAS** : Vérification de l'absence de données nominatives résiduelles.
- **Disclaimers** : Ajout systématique d'un avertissement si le contenu touche au domaine clinique.

## Niveau 4 — Limites d'Exécution (Bounded Execution)

Des limites strictes empêchent les comportements émergents non désirés :
- **Budget tokens** : Maximum par session (défaut : 32 000 tokens).
- **Profondeur de récursion** : Maximum de 3 niveaux de délégation entre agents.
- **Timeout** : Limite globale de 120 secondes par requête.
- **Boucles infinies** : Nombre maximum d'appels d'outils par tour limité à 10.
