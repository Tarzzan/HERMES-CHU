<div align="center">
  <h1 style="color: #0052cc;">🛡️ Conformité ISO 27001 & HDS</h1>
</div>

<br/>

La norme ISO 27001 exige la mise en place d'un Système de Management de la Sécurité de l'Information (SMSI). Le tableau suivant détaille comment chaque exigence clé de la norme est satisfaite par l'architecture HERMES CHU.

## Alignement par Clause ISO 27001

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #0052cc; color: white;">
      <th style="padding: 12px; text-align: left;">Clause ISO 27001</th>
      <th style="padding: 12px; text-align: left;">Exigence</th>
      <th style="padding: 12px; text-align: left;">Implémentation HERMES CHU</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.5 — Politiques</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Politiques documentées et révisées</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Fichier <code>SECURITY_POLICY.md</code> versionné, révisé trimestriellement.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.6 — Organisation</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Rôles et responsabilités définis</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">RBAC via Keycloak avec 5 rôles stricts (Admin, Clinicien, Qualiticien, RSSI, Auditeur).</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.8 — Actifs</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Inventaire et classification</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Registre automatique des outils et modèles via le <em>Tool Registry</em>.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.9 — Contrôle d'accès</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Authentification forte</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">MFA obligatoire + LDAP CHU + JWT à courte durée de vie (15 min).</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.10 — Cryptographie</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Chiffrement des données</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">TLS 1.3 (transit), AES-256-GCM (repos pour SQLite), Redis chiffré.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.12 — Opérations</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Journalisation et surveillance</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Journal d'audit immuable PostgreSQL + alertes Prometheus/Grafana.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.14 — Développement</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Sécurité by design</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Tests SAST/DAST dans la CI/CD, scan Trivy des images Docker.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>A.16 — Incidents</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Détection et réponse</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Circuit d'alerte automatique si un agent tente une action non autorisée.</td>
    </tr>
  </tbody>
</table>

## Certification HDS (Hébergeur de Données de Santé)

La certification HDS impose des exigences supplémentaires spécifiques aux données de santé. HERMES CHU y répond par :

1. **Hébergement physique** : Tous les composants sont déployés sur une infrastructure certifiée HDS (datacenter souverain français ou infrastructure propre du CHU).
2. **Isolation réseau** : Le cluster Kubernetes est isolé dans un VLAN dédié, sans accès Internet sortant (sauf proxy filtrant pour l'Agent Recherche).
3. **Sauvegarde et PRA** : Sauvegardes chiffrées quotidiennes avec rétention de 90 jours. Plan de Reprise d'Activité testé semestriellement.
