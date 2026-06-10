<div align="center">
  <img src="https://img.shields.io/badge/HERMES--CHU-Système_Agentique_Hospitalier-0052cc?style=for-the-badge" alt="HERMES CHU Logo" />
</div>

<br/>

<div style="background-color: #f8f9fa; border-left: 5px solid #0052cc; padding: 20px; border-radius: 4px; margin-bottom: 30px;">
  <h2 style="margin-top: 0; color: #0052cc;">☤ Bienvenue sur le Wiki de HERMES CHU</h2>
  <p style="font-size: 16px; line-height: 1.6;">
    <strong>HERMES CHU</strong> est un système nerveux numérique conçu pour les Centres Hospitaliers Universitaires. 
    Basé sur l'orchestrateur open-source <a href="https://github.com/NousResearch/hermes-agent">Hermes Agent</a>, il apporte la puissance de l'IA multi-agents dans un cadre de <strong>souveraineté totale</strong> et de <strong>conformité ISO 27001 / HDS</strong>.
  </p>
</div>

## 🎯 Vision et Ambition

Les CHU font face à une surcharge administrative considérable. Le codage des actes médicaux, la rédaction de comptes-rendus, la coordination inter-services et le suivi qualité génèrent un volume de tâches répétitives. 

L'ambition de HERMES CHU n'est pas d'être un simple assistant conversationnel, mais un **orchestrateur autonome** capable de :
- Décomposer des tâches complexes
- Déléguer à des agents spécialisés (Clinique, Administratif, Logistique)
- Garantir le secret médical par une anonymisation déterministe par défaut
- Tracer chaque décision pour les audits qualité

## 🔐 Principes Non-Négociables

<table style="width: 100%; border-collapse: collapse; margin-bottom: 30px;">
  <thead>
    <tr style="background-color: #0052cc; color: white;">
      <th style="padding: 12px; text-align: left;">Principe</th>
      <th style="padding: 12px; text-align: left;">Description Technique</th>
    </tr>
  </thead>
  <tbody>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Souveraineté totale</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Aucune donnée ne quitte l'infrastructure HDS. Le LLM (Hermes-3-70B) est hébergé localement.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Anonymisation par défaut</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Le LLM ne traite jamais de données nominatives. Le SAS d'anonymisation NER est systématique.</td>
    </tr>
    <tr style="background-color: #f8f9fa;">
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Humain dans la boucle</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Toute action critique (écriture DPI, envoi externe) nécessite une validation explicite via l'interface.</td>
    </tr>
    <tr>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;"><strong>Transparence</strong></td>
      <td style="padding: 12px; border-bottom: 1px solid #ddd;">Chaque décision, délégation et appel de fonction est tracé dans un journal d'audit immuable (PostgreSQL append-only).</td>
    </tr>
  </tbody>
</table>

## 🗺️ Navigation dans le Wiki

<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
  <div style="border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px;">
    <h3 style="color: #0052cc; margin-top: 0;">🏗️ Architecture</h3>
    <ul>
      <li><a href="02-Architecture-Technique">Architecture Technique Globale</a></li>
      <li><a href="03-Coeur-Agentique">Le Cœur Agentique (Hermes)</a></li>
      <li><a href="04-Agents-Specialises">Réseau d'Agents Spécialisés</a></li>
    </ul>
  </div>
  
  <div style="border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px;">
    <h3 style="color: #e36209; margin-top: 0;">🛡️ Sécurité & Conformité</h3>
    <ul>
      <li><a href="05-SAS-Anonymisation">SAS d'Anonymisation (Privacy Engine)</a></li>
      <li><a href="06-Conformite-ISO-27001">Conformité ISO 27001 & HDS</a></li>
      <li><a href="07-Garde-Fous">Système de Garde-Fous à 4 Niveaux</a></li>
    </ul>
  </div>
  
  <div style="border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px;">
    <h3 style="color: #28a745; margin-top: 0;">💻 Interfaces & APIs</h3>
    <ul>
      <li><a href="08-Interface-Web">Interface Web de Pilotage</a></li>
      <li><a href="09-APIs-Qualite">APIs REST de Suivi Qualité</a></li>
    </ul>
  </div>
  
  <div style="border: 1px solid #e1e4e8; border-radius: 6px; padding: 15px;">
    <h3 style="color: #6f42c1; margin-top: 0;">🚀 Déploiement</h3>
    <ul>
      <li><a href="10-Deploiement">Infrastructure Kubernetes</a></li>
      <li><a href="11-Roadmap">Roadmap Détaillée</a></li>
    </ul>
  </div>
</div>

<br/>
<hr/>
<div align="center">
  <small><em>Wiki généré et maintenu par l'équipe HERMES CHU — 2026</em></small>
</div>
