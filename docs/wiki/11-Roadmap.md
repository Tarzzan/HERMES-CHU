<div align="center">
  <h1 style="color: #0052cc;">🗺️ Roadmap HERMES CHU</h1>
  <p><em>Planification détaillée du déploiement du système agentique hospitalier</em></p>
</div>

<br/>

Le déploiement de HERMES CHU est structuré en **6 phases progressives**, s'étalant sur 18 mois. Cette approche incrémentale permet de valider la sécurité (Phase 2) avant d'introduire des agents autonomes (Phase 3), et de tester en conditions réelles (Phase 5) avant le déploiement généralisé (Phase 6).

---

## <span style="background-color: #0052cc; color: white; padding: 4px 10px; border-radius: 4px;">Phase 1</span> Fondations & Infrastructure (Mois 1-3)

Mise en place du socle technique souverain et sécurisé.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>INFRA-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Provisionner le cluster Kubernetes certifié HDS</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>INFRA-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Déployer vLLM avec Hermes-3-Llama-3.1-70B local</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>ORCH-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Adapter Hermes Agent en orchestrateur CHU francisé</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>INFRA-004</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Configurer Keycloak avec intégration LDAP/AD du CHU</td>
  </tr>
</table>

---

## <span style="background-color: #e36209; color: white; padding: 4px 10px; border-radius: 4px;">Phase 2</span> Sécurité & Anonymisation (Mois 4-6)

Développement du Privacy Engine et des garde-fous pour garantir le secret médical.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>PRIV-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer le modèle NER clinique français (CamemBERT-bio)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>PRIV-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Implémenter le pipeline de pseudonymisation réversible</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>SEC-001/003</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Implémenter les garde-fous à 4 niveaux (Input, Tool, Output, Bounded)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>SEC-004</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Mettre en place le journal d'audit immuable (ISO 27001)</td>
  </tr>
</table>

---

## <span style="background-color: #6f42c1; color: white; padding: 4px 10px; border-radius: 4px;">Phase 3</span> Agents Spécialisés & SIH (Mois 7-9)

Création de l'intelligence métier et connexion au Dossier Patient Informatisé.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>AGENT-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer l'Agent Clinique (synthèse médicale pour RCP)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>AGENT-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer l'Agent Administratif (gestion documentaire)</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>SIH-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer le connecteur HL7 FHIR R4 pour le DPI (lecture)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>ORCH-003</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Implémenter le système de délégation multi-agents (Function Calling)</td>
  </tr>
</table>

---

## <span style="background-color: #28a745; color: white; padding: 4px 10px; border-radius: 4px;">Phase 4</span> Interface Web & APIs Qualité (Mois 10-12)

Développement des interfaces utilisateurs et des outils de supervision.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>UI-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer l'espace Dialogue (Chat Orchestrateur avec Human-in-the-Loop)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>UI-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Développer l'espace Supervision (Dashboard Agents)</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>API-001/004</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Implémenter les APIs REST de suivi qualité (Anonymisation, Audit, Usage)</td>
  </tr>
</table>

---

## <span style="background-color: #d73a49; color: white; padding: 4px 10px; border-radius: 4px;">Phase 5</span> Pilote & Validation Clinique (Mois 13-15)

Tests en conditions réelles et audit de sécurité externe.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>PILOT-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Déployer le système dans 2 services pilotes (ex: Urgences, Cardiologie)</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>SEC-005</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Audit de sécurité externe (Pentest de l'API et du modèle NER)</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>PILOT-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Intégration DPI en écriture (mode supervisé avec double validation)</td>
  </tr>
</table>

---

## <span style="background-color: #24292e; color: white; padding: 4px 10px; border-radius: 4px;">Phase 6</span> Production & Amélioration (Mois 16+)

Généralisation à tout l'hôpital et certification officielle.

<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd; width: 15%;"><strong>PROD-001</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Extension multi-services et auto-scaling de l'infrastructure</td>
  </tr>
  <tr>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>PROD-002</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Certification HDS finale et audit ISO 27001 par organisme tiers</td>
  </tr>
  <tr style="background-color: #f8f9fa;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>PROD-003</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;">Programme de formation continue des utilisateurs</td>
  </tr>
</table>
