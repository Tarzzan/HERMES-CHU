<div align="center">
  <h1 style="color: #0052cc;">⚙️ Le Cœur Agentique — Hermes Core</h1>
</div>

<br/>

Le cœur agentique de HERMES CHU est une adaptation du framework open-source **Hermes Agent** de NousResearch. Il constitue le cerveau du système : c'est lui qui reçoit les requêtes (déjà anonymisées), les décompose en sous-tâches, délègue aux agents spécialisés, et synthétise les résultats.

## Adaptation de Hermes Agent pour le CHU

L'architecture originale de Hermes Agent repose sur trois piliers que nous conservons et étendons :

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #6f42c1; color: white;">
      <th style="padding: 12px; text-align: left;">Composant Hermes</th>
      <th style="padding: 12px; text-align: left;">Rôle Original</th>
      <th style="padding: 12px; text-align: left;">Adaptation CHU</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Agent Loop</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Boucle Think → Act → Observe</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Ajout d'un état <code>VALIDATE</code> pour le Human-in-the-Loop sur actions critiques.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Function Calling</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Appel d'outils via JSON structuré</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Extension avec un <em>Tool Registry</em> dynamique et validation RBAC pré-appel.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Memory</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Mémoire de session SQLite</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Chiffrement AES-256-GCM + TTL configurable + purge automatique.</td>
    </tr>
  </tbody>
</table>

## Boucle Agentique Étendue

La boucle principale de l'Agent Pilote suit un cycle en 5 étapes (au lieu de 3 dans Hermes standard) :

1. **THINK** — Le LLM analyse la requête et planifie les étapes nécessaires.
2. **DELEGATE** — L'orchestrateur identifie le ou les agents spécialisés à mobiliser.
3. **ACT** — L'agent spécialisé exécute sa tâche via des appels de fonctions.
4. **VALIDATE** — Si l'action est classée "critique" (écriture DPI, envoi externe), une demande de validation est envoyée à l'utilisateur via l'interface web.
5. **OBSERVE** — Le résultat est collecté, synthétisé et renvoyé à l'utilisateur.

## Modèle LLM : Hermes-3-Llama-3.1-70B

Le modèle utilisé est `NousResearch/Hermes-3-Llama-3.1-70B-Instruct`, servi localement via vLLM. Ce choix garantit :

- **Souveraineté** : Aucune donnée ne transite vers un cloud externe.
- **Performance** : Le format ChatML natif de Hermes est optimisé pour le function calling.
- **Francisation** : Le modèle est affiné sur des corpus français médicaux pour améliorer la qualité des réponses.

## System Prompt de l'Agent Pilote

Le system prompt de l'Agent Pilote est rédigé intégralement en français et définit :
- Son identité (assistant hospitalier, pas médecin)
- Ses limites (jamais de diagnostic, toujours orienter vers le praticien)
- Son périmètre d'action (outils autorisés selon le contexte)
- Les règles de délégation (quand et à qui déléguer)

Ce prompt est versionné dans le dépôt et toute modification nécessite une revue par le RSSI.
