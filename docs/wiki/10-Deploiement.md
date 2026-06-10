<div align="center">
  <h1 style="color: #0052cc;">🚀 Déploiement & Infrastructure Kubernetes</h1>
</div>

<br/>

L'infrastructure de HERMES CHU est conçue pour un déploiement sur un cluster Kubernetes certifié HDS, garantissant haute disponibilité, isolation réseau et conformité réglementaire.

## Architecture de Déploiement

<img src="https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/docs/architecture/deployment_diagram.png" alt="Diagramme de Déploiement" width="100%" />

## Namespaces Kubernetes

Le cluster est organisé en namespaces isolés pour respecter le principe de moindre privilège :

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #64748b; color: white;">
      <th style="padding: 12px; text-align: left;">Namespace</th>
      <th style="padding: 12px; text-align: left;">Composants</th>
      <th style="padding: 12px; text-align: left;">Politique Réseau</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-inference</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">vLLM (2x GPU A100 80GB), modèle Hermes-3-70B</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Ingress uniquement depuis <code>hermes-core</code></td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-core</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Orchestrateur, Privacy Engine, Garde-fous</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Ingress depuis <code>hermes-gateway</code>, egress vers <code>hermes-inference</code> et <code>hermes-agents</code></td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-agents</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Conteneurs des 5 agents spécialisés</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Ingress uniquement depuis <code>hermes-core</code></td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-gateway</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">API Gateway (Kong), Keycloak, Interface Web</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Exposé via Ingress Controller (TLS 1.3)</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-data</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">PostgreSQL (audit), Redis Cluster (anonymisation)</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Ingress uniquement depuis <code>hermes-core</code></td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><code>hermes-monitoring</code></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Prometheus, Grafana, Loki, AlertManager</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Lecture depuis tous les namespaces</td>
    </tr>
  </tbody>
</table>

## Ressources Matérielles Minimales

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #64748b; color: white;">
      <th style="padding: 12px; text-align: left;">Composant</th>
      <th style="padding: 12px; text-align: center;">CPU</th>
      <th style="padding: 12px; text-align: center;">RAM</th>
      <th style="padding: 12px; text-align: center;">GPU</th>
      <th style="padding: 12px; text-align: center;">Stockage</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">vLLM (inférence)</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">16 cores</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">128 Go</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">2x A100 80GB</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">500 Go NVMe</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Orchestrateur + Agents</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">32 cores</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">64 Go</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">—</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">200 Go SSD</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Bases de données</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">8 cores</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">32 Go</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">—</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">1 To SSD (RAID)</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">NER (CamemBERT-bio)</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">8 cores</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">16 Go</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">1x T4 16GB</td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd; text-align: center;">50 Go</td>
    </tr>
  </tbody>
</table>

## CI/CD Sécurisée

Le pipeline CI/CD est conçu pour garantir la sécurité à chaque étape :

1. **Commit** → Lint + Tests unitaires
2. **Build** → Construction des images Docker (multi-stage, distroless)
3. **Scan** → Trivy (vulnérabilités), Semgrep (SAST), Gitleaks (secrets)
4. **Deploy staging** → Déploiement automatique sur l'environnement de pré-production
5. **Tests d'intégration** → Validation end-to-end avec données synthétiques
6. **Deploy production** → Déploiement manuel (approbation RSSI requise)

## Haute Disponibilité

- **Réplication** : Tous les composants critiques sont répliqués (min 2 pods).
- **Auto-scaling** : HPA configuré pour les agents (scale-out sur charge CPU > 70%).
- **PRA** : Sauvegardes chiffrées quotidiennes, RTO < 4h, RPO < 1h.
