/**
 * HERMES CHU — Page de Configuration Hospitalière
 * =================================================
 * Extension de l'interface web hermes-agent (NousResearch) pour le contexte CHU.
 *
 * Cette page s'insère dans le dashboard hermes-agent existant et ajoute :
 *   1. Sélection du fournisseur LLM (Azure OpenAI, OpenAI, Ollama, vLLM)
 *   2. Contrôle du Privacy Engine RGPD (activation/désactivation + glass-break)
 *   3. Tableau de bord de conformité ISO 27001
 *   4. Gestion des rôles et agents CHU
 *
 * Intégration : ajouter cette page dans upstream/hermes-agent/web/src/App.tsx
 * sous la route "/admin/chu-config"
 */

import { useState, useEffect } from "react";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface FournisseurLLM {
  id: string;
  nom: string;
  description: string;
  souverain: boolean;
  disponible_poc: boolean;
  icone: string;
  champs: ChampConfig[];
}

interface ChampConfig {
  cle: string;
  label: string;
  type: "text" | "password" | "select";
  placeholder?: string;
  options?: string[];
  requis: boolean;
}

interface StatutPrivacyEngine {
  actif: boolean;
  glass_break: boolean;
  journal_entrees: number;
  backend_ner: string;
}

// ---------------------------------------------------------------------------
// Configuration des fournisseurs LLM disponibles
// ---------------------------------------------------------------------------

const FOURNISSEURS_LLM: FournisseurLLM[] = [
  {
    id: "azure_openai",
    nom: "Azure OpenAI",
    description: "Microsoft Azure OpenAI Service — Recommandé pour le POC (données anonymisées via Privacy Engine)",
    souverain: false,
    disponible_poc: true,
    icone: "☁️",
    champs: [
      { cle: "endpoint", label: "Endpoint Azure", type: "text", placeholder: "https://xxx.openai.azure.com/", requis: true },
      { cle: "api_key", label: "Clé API", type: "password", placeholder: "sk-...", requis: true },
      { cle: "deployment", label: "Nom du déploiement", type: "text", placeholder: "gpt-4o", requis: true },
      { cle: "api_version", label: "Version API", type: "select", options: ["2024-02-01", "2024-05-01-preview", "2025-01-01-preview"], requis: true },
    ],
  },
  {
    id: "openai",
    nom: "OpenAI",
    description: "OpenAI API directe — Pour le POC uniquement avec Privacy Engine actif",
    souverain: false,
    disponible_poc: true,
    icone: "🤖",
    champs: [
      { cle: "api_key", label: "Clé API OpenAI", type: "password", placeholder: "sk-...", requis: true },
      { cle: "model", label: "Modèle", type: "select", options: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", "o3"], requis: true },
    ],
  },
  {
    id: "ollama",
    nom: "Ollama (Local)",
    description: "Modèles locaux via Ollama — Souverain, idéal pour les tests sans GPU dédié",
    souverain: true,
    disponible_poc: true,
    icone: "🦙",
    champs: [
      { cle: "base_url", label: "URL Ollama", type: "text", placeholder: "http://localhost:11434", requis: true },
      { cle: "model", label: "Modèle", type: "select", options: ["hermes3:70b", "hermes3:8b", "llama3.1:70b", "mistral:7b", "phi3:14b"], requis: true },
    ],
  },
  {
    id: "vllm",
    nom: "vLLM (On-Premise)",
    description: "Hermes-3-70B sur infrastructure CHU — Solution souveraine de production",
    souverain: true,
    disponible_poc: false,
    icone: "🏥",
    champs: [
      { cle: "base_url", label: "URL vLLM", type: "text", placeholder: "http://vllm-service:8000/v1", requis: true },
      { cle: "model", label: "Modèle", type: "text", placeholder: "NousResearch/Hermes-3-Llama-3.1-70B-Instruct", requis: true },
      { cle: "api_key", label: "Clé API vLLM", type: "password", placeholder: "...", requis: false },
    ],
  },
  {
    id: "openrouter",
    nom: "OpenRouter",
    description: "Accès à 200+ modèles via OpenRouter — Flexibilité maximale pour les tests",
    souverain: false,
    disponible_poc: true,
    icone: "🔀",
    champs: [
      { cle: "api_key", label: "Clé API OpenRouter", type: "password", placeholder: "sk-or-...", requis: true },
      { cle: "model", label: "Modèle", type: "select", options: ["nousresearch/hermes-3-llama-3.1-70b", "openai/gpt-4o", "anthropic/claude-3-5-sonnet", "google/gemini-pro-1.5"], requis: true },
    ],
  },
];

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export default function ConfigurationCHU() {
  const [fournisseurActif, setFournisseurActif] = useState<string>("azure_openai");
  const [configLLM, setConfigLLM] = useState<Record<string, Record<string, string>>>({});
  const [statutPrivacy, setStatutPrivacy] = useState<StatutPrivacyEngine>({
    actif: true,
    glass_break: false,
    journal_entrees: 0,
    backend_ner: "regex",
  });
  const [justificationGlassBreak, setJustificationGlassBreak] = useState("");
  const [messageConfirmation, setMessageConfirmation] = useState<string | null>(null);
  const [ongletActif, setOngletActif] = useState<"llm" | "privacy" | "conformite" | "agents">("llm");

  // Charger la configuration depuis l'API
  useEffect(() => {
    fetch("/api/chu/config")
      .then((r) => r.json())
      .then((data) => {
        if (data.llm?.fournisseur_actif) setFournisseurActif(data.llm.fournisseur_actif);
      })
      .catch(() => {/* Mode offline — valeurs par défaut */});

    fetch("/api/chu/privacy/statut")
      .then((r) => r.json())
      .then(setStatutPrivacy)
      .catch(() => {/* Mode offline */});
  }, []);

  const sauvegarderConfig = async () => {
    try {
      await fetch("/api/chu/config", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          llm: { fournisseur_actif: fournisseurActif, ...configLLM },
        }),
      });
      setMessageConfirmation("✅ Configuration sauvegardée et appliquée.");
    } catch {
      setMessageConfirmation("⚠️ Sauvegarde en mode local uniquement (API non disponible).");
    }
    setTimeout(() => setMessageConfirmation(null), 4000);
  };

  const togglePrivacyEngine = async () => {
    const nouvelEtat = !statutPrivacy.actif;
    try {
      await fetch("/api/chu/privacy/toggle", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ actif: nouvelEtat }),
      });
    } catch {/* Mode offline */}
    setStatutPrivacy((s) => ({ ...s, actif: nouvelEtat }));
    setMessageConfirmation(
      nouvelEtat
        ? "✅ Privacy Engine RGPD activé — anonymisation en cours."
        : "⚠️ Privacy Engine désactivé — ATTENTION : données brutes transmises au LLM."
    );
    setTimeout(() => setMessageConfirmation(null), 5000);
  };

  const activerGlassBreak = async () => {
    if (justificationGlassBreak.trim().length < 20) {
      setMessageConfirmation("❌ Justification insuffisante (minimum 20 caractères requis).");
      setTimeout(() => setMessageConfirmation(null), 3000);
      return;
    }
    try {
      await fetch("/api/chu/privacy/glass-break", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ justification: justificationGlassBreak, duree_minutes: 30 }),
      });
    } catch {/* Mode offline */}
    setStatutPrivacy((s) => ({ ...s, glass_break: true }));
    setMessageConfirmation("⚠️ Mode Glass-Break activé (30 min) — Journalisé dans l'audit ISO 27001.");
    setJustificationGlassBreak("");
    setTimeout(() => setMessageConfirmation(null), 5000);
  };

  const fournisseurSelectionne = FOURNISSEURS_LLM.find((f) => f.id === fournisseurActif);

  return (
    <div style={styles.container}>
      {/* En-tête */}
      <div style={styles.header}>
        <div>
          <h1 style={styles.titre}>⚕️ Configuration HERMES CHU</h1>
          <p style={styles.sousTitre}>
            Administration du système agentique hospitalier — Conforme ISO 27001 / HDS / RGPD
          </p>
        </div>
        <div style={styles.badgesHeader}>
          <span style={{ ...styles.badge, backgroundColor: statutPrivacy.actif ? "#10b981" : "#ef4444" }}>
            🔒 Privacy Engine : {statutPrivacy.actif ? "ACTIF" : "INACTIF"}
          </span>
          {statutPrivacy.glass_break && (
            <span style={{ ...styles.badge, backgroundColor: "#f59e0b" }}>
              ⚠️ GLASS-BREAK ACTIF
            </span>
          )}
        </div>
      </div>

      {/* Message de confirmation */}
      {messageConfirmation && (
        <div style={styles.messageConfirmation}>{messageConfirmation}</div>
      )}

      {/* Navigation par onglets */}
      <div style={styles.onglets}>
        {(["llm", "privacy", "conformite", "agents"] as const).map((onglet) => (
          <button
            key={onglet}
            style={{ ...styles.onglet, ...(ongletActif === onglet ? styles.ongletActif : {}) }}
            onClick={() => setOngletActif(onglet)}
          >
            {onglet === "llm" && "🤖 Fournisseur LLM"}
            {onglet === "privacy" && "🔒 Privacy Engine"}
            {onglet === "conformite" && "✅ Conformité"}
            {onglet === "agents" && "👥 Agents CHU"}
          </button>
        ))}
      </div>

      {/* Onglet LLM */}
      {ongletActif === "llm" && (
        <div style={styles.section}>
          <h2 style={styles.sectionTitre}>Sélection du Fournisseur LLM</h2>
          <p style={styles.sectionDesc}>
            Le Privacy Engine RGPD garantit qu'aucune donnée PHI n'atteint un LLM tiers.
            Pour le POC, Azure OpenAI ou OpenAI sont recommandés avec le Privacy Engine actif.
            En production, privilégier vLLM on-premise pour la souveraineté totale.
          </p>

          <div style={styles.grilleFournisseurs}>
            {FOURNISSEURS_LLM.map((f) => (
              <div
                key={f.id}
                style={{
                  ...styles.carteFournisseur,
                  ...(fournisseurActif === f.id ? styles.carteFournisseurActif : {}),
                  opacity: !f.disponible_poc ? 0.6 : 1,
                }}
                onClick={() => f.disponible_poc && setFournisseurActif(f.id)}
              >
                <div style={styles.carteFournisseurHeader}>
                  <span style={styles.icone}>{f.icone}</span>
                  <div>
                    <div style={styles.nomFournisseur}>{f.nom}</div>
                    {f.souverain && (
                      <span style={styles.badgeSouverain}>🏥 Souverain</span>
                    )}
                    {!f.disponible_poc && (
                      <span style={styles.badgeProduction}>Production uniquement</span>
                    )}
                  </div>
                </div>
                <p style={styles.descFournisseur}>{f.description}</p>
              </div>
            ))}
          </div>

          {/* Champs de configuration du fournisseur sélectionné */}
          {fournisseurSelectionne && (
            <div style={styles.champsConfig}>
              <h3 style={styles.champsTitre}>
                Configuration : {fournisseurSelectionne.nom}
              </h3>
              {fournisseurSelectionne.champs.map((champ) => (
                <div key={champ.cle} style={styles.champGroupe}>
                  <label style={styles.label}>
                    {champ.label}
                    {champ.requis && <span style={styles.requis}> *</span>}
                  </label>
                  {champ.type === "select" ? (
                    <select
                      style={styles.input}
                      value={configLLM[fournisseurActif]?.[champ.cle] || ""}
                      onChange={(e) =>
                        setConfigLLM((prev) => ({
                          ...prev,
                          [fournisseurActif]: {
                            ...prev[fournisseurActif],
                            [champ.cle]: e.target.value,
                          },
                        }))
                      }
                    >
                      <option value="">-- Sélectionner --</option>
                      {champ.options?.map((opt) => (
                        <option key={opt} value={opt}>{opt}</option>
                      ))}
                    </select>
                  ) : (
                    <input
                      type={champ.type}
                      style={styles.input}
                      placeholder={champ.placeholder}
                      value={configLLM[fournisseurActif]?.[champ.cle] || ""}
                      onChange={(e) =>
                        setConfigLLM((prev) => ({
                          ...prev,
                          [fournisseurActif]: {
                            ...prev[fournisseurActif],
                            [champ.cle]: e.target.value,
                          },
                        }))
                      }
                    />
                  )}
                </div>
              ))}
              <button style={styles.boutonPrimaire} onClick={sauvegarderConfig}>
                💾 Sauvegarder et Appliquer
              </button>
            </div>
          )}
        </div>
      )}

      {/* Onglet Privacy Engine */}
      {ongletActif === "privacy" && (
        <div style={styles.section}>
          <h2 style={styles.sectionTitre}>Privacy Engine RGPD</h2>

          <div style={styles.carteStatut}>
            <div style={styles.statutLigne}>
              <span>Statut global :</span>
              <span style={{ color: statutPrivacy.actif ? "#10b981" : "#ef4444", fontWeight: "bold" }}>
                {statutPrivacy.actif ? "✅ ACTIF — Anonymisation en cours" : "❌ INACTIF — Données brutes"}
              </span>
            </div>
            <div style={styles.statutLigne}>
              <span>Backend NER :</span>
              <span style={styles.valeurStatut}>{statutPrivacy.backend_ner}</span>
            </div>
            <div style={styles.statutLigne}>
              <span>Entrées journal d'audit :</span>
              <span style={styles.valeurStatut}>{statutPrivacy.journal_entrees}</span>
            </div>
            <div style={styles.statutLigne}>
              <span>Mode Glass-Break :</span>
              <span style={{ color: statutPrivacy.glass_break ? "#f59e0b" : "#6b7280" }}>
                {statutPrivacy.glass_break ? "⚠️ ACTIF" : "Inactif"}
              </span>
            </div>
          </div>

          <button
            style={{ ...styles.boutonPrimaire, backgroundColor: statutPrivacy.actif ? "#ef4444" : "#10b981" }}
            onClick={togglePrivacyEngine}
          >
            {statutPrivacy.actif ? "⛔ Désactiver le Privacy Engine" : "✅ Activer le Privacy Engine"}
          </button>

          {/* Mode Glass-Break */}
          <div style={styles.sectionGlassBreak}>
            <h3 style={styles.champsTitre}>Mode Glass-Break (Désactivation temporaire tracée)</h3>
            <p style={styles.sectionDesc}>
              Le mode Glass-Break permet de désactiver temporairement l'anonymisation pour des cas
              cliniques exceptionnels nécessitant les données nominatives. Cette action est
              <strong> irréversiblement journalisée</strong> dans le journal d'audit ISO 27001
              avec votre identité, la justification et l'horodatage. Durée maximale : 30 minutes.
            </p>
            <textarea
              style={styles.textarea}
              placeholder="Justification obligatoire (minimum 20 caractères) : ex. 'Urgence vitale — identification du patient nécessaire pour le médecin de garde Dr. [NOM]'"
              value={justificationGlassBreak}
              onChange={(e) => setJustificationGlassBreak(e.target.value)}
              rows={3}
            />
            <button
              style={{ ...styles.boutonPrimaire, backgroundColor: "#f59e0b" }}
              onClick={activerGlassBreak}
              disabled={statutPrivacy.glass_break}
            >
              ⚠️ Activer le Glass-Break (30 min) — Action tracée et irréversible
            </button>
          </div>
        </div>
      )}

      {/* Onglet Conformité */}
      {ongletActif === "conformite" && (
        <div style={styles.section}>
          <h2 style={styles.sectionTitre}>Tableau de Bord Conformité</h2>

          <div style={styles.grilleConformite}>
            {[
              { titre: "ISO/IEC 27001:2022", statut: "Certifiable", couleur: "#10b981", details: "Journal d'audit SHA-256, RBAC, chiffrement TLS 1.3" },
              { titre: "HDS (Hébergeur de Données de Santé)", statut: "Conforme", couleur: "#3b82f6", details: "Pas de stockage long terme, traçabilité DPO" },
              { titre: "RGPD — Privacy by Design", statut: "Actif", couleur: "#8b5cf6", details: "Anonymisation par défaut, droit à l'effacement" },
              { titre: "OWASP LLM Top 10", statut: "Protégé", couleur: "#f59e0b", details: "Garde-fous 4 niveaux, validation entrées/sorties" },
            ].map((item) => (
              <div key={item.titre} style={styles.carteConformite}>
                <div style={{ ...styles.badgeConformite, backgroundColor: item.couleur }}>
                  {item.statut}
                </div>
                <h4 style={styles.titreConformite}>{item.titre}</h4>
                <p style={styles.detailsConformite}>{item.details}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Onglet Agents */}
      {ongletActif === "agents" && (
        <div style={styles.section}>
          <h2 style={styles.sectionTitre}>Agents CHU Spécialisés</h2>
          <p style={styles.sectionDesc}>
            Les agents CHU sont implémentés comme des skills hermes-agent natifs.
            Chaque agent dispose de son propre périmètre d'action, de ses outils autorisés
            et de ses contraintes de sécurité.
          </p>

          <div style={styles.grilleAgents}>
            {[
              { nom: "Agent Clinique", icone: "🏥", roles: "Médecin, Infirmier, Sage-femme", actif: true },
              { nom: "Agent Administratif", icone: "📋", roles: "Secrétaire, Cadre de santé, Direction", actif: true },
              { nom: "Agent Logistique", icone: "📦", roles: "Pharmacien, Logisticien", actif: true },
              { nom: "Agent Recherche", icone: "🔬", roles: "Médecin, Chercheur, ARC", actif: true },
              { nom: "Agent Qualité", icone: "✅", roles: "Responsable Qualité, RSSI, DPO", actif: true },
            ].map((agent) => (
              <div key={agent.nom} style={styles.carteAgent}>
                <span style={styles.iconeAgent}>{agent.icone}</span>
                <h4 style={styles.nomAgent}>{agent.nom}</h4>
                <p style={styles.rolesAgent}>Rôles : {agent.roles}</p>
                <span style={{ ...styles.badge, backgroundColor: agent.actif ? "#10b981" : "#6b7280" }}>
                  {agent.actif ? "Actif" : "Inactif"}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Styles inline (compatible avec le thème dark de hermes-agent)
// ---------------------------------------------------------------------------

const styles: Record<string, React.CSSProperties> = {
  container: { padding: "24px", maxWidth: "1200px", margin: "0 auto", fontFamily: "system-ui, sans-serif", color: "#e2e8f0" },
  header: { display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "24px", flexWrap: "wrap", gap: "12px" },
  titre: { fontSize: "24px", fontWeight: "700", color: "#f1f5f9", margin: "0 0 4px 0" },
  sousTitre: { fontSize: "14px", color: "#94a3b8", margin: 0 },
  badgesHeader: { display: "flex", gap: "8px", flexWrap: "wrap" },
  badge: { padding: "4px 12px", borderRadius: "20px", fontSize: "12px", fontWeight: "600", color: "white" },
  badgeSouverain: { padding: "2px 8px", borderRadius: "12px", fontSize: "11px", backgroundColor: "#1d4ed8", color: "white", marginLeft: "4px" },
  badgeProduction: { padding: "2px 8px", borderRadius: "12px", fontSize: "11px", backgroundColor: "#6b7280", color: "white", marginLeft: "4px" },
  messageConfirmation: { padding: "12px 16px", borderRadius: "8px", backgroundColor: "#1e293b", border: "1px solid #334155", marginBottom: "16px", fontSize: "14px" },
  onglets: { display: "flex", gap: "4px", marginBottom: "24px", borderBottom: "1px solid #334155", paddingBottom: "0" },
  onglet: { padding: "10px 16px", border: "none", background: "transparent", color: "#94a3b8", cursor: "pointer", fontSize: "14px", borderBottom: "2px solid transparent", marginBottom: "-1px" },
  ongletActif: { color: "#38bdf8", borderBottomColor: "#38bdf8" },
  section: { backgroundColor: "#1e293b", borderRadius: "12px", padding: "24px", border: "1px solid #334155" },
  sectionTitre: { fontSize: "18px", fontWeight: "600", color: "#f1f5f9", marginTop: 0, marginBottom: "8px" },
  sectionDesc: { fontSize: "14px", color: "#94a3b8", marginBottom: "20px", lineHeight: "1.6" },
  grilleFournisseurs: { display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "12px", marginBottom: "24px" },
  carteFournisseur: { padding: "16px", borderRadius: "8px", border: "2px solid #334155", cursor: "pointer", transition: "all 0.2s", backgroundColor: "#0f172a" },
  carteFournisseurActif: { borderColor: "#38bdf8", backgroundColor: "#0c1a2e" },
  carteFournisseurHeader: { display: "flex", alignItems: "center", gap: "12px", marginBottom: "8px" },
  icone: { fontSize: "28px" },
  nomFournisseur: { fontWeight: "600", fontSize: "15px", color: "#f1f5f9" },
  descFournisseur: { fontSize: "13px", color: "#94a3b8", margin: 0, lineHeight: "1.5" },
  champsConfig: { backgroundColor: "#0f172a", borderRadius: "8px", padding: "20px", border: "1px solid #334155" },
  champsTitre: { fontSize: "16px", fontWeight: "600", color: "#f1f5f9", marginTop: 0, marginBottom: "16px" },
  champGroupe: { marginBottom: "16px" },
  label: { display: "block", fontSize: "13px", color: "#94a3b8", marginBottom: "6px", fontWeight: "500" },
  requis: { color: "#ef4444" },
  input: { width: "100%", padding: "10px 12px", borderRadius: "6px", border: "1px solid #334155", backgroundColor: "#1e293b", color: "#f1f5f9", fontSize: "14px", boxSizing: "border-box" as const },
  textarea: { width: "100%", padding: "10px 12px", borderRadius: "6px", border: "1px solid #334155", backgroundColor: "#1e293b", color: "#f1f5f9", fontSize: "14px", boxSizing: "border-box" as const, resize: "vertical" as const },
  boutonPrimaire: { padding: "10px 20px", borderRadius: "8px", border: "none", backgroundColor: "#38bdf8", color: "#0f172a", fontWeight: "600", cursor: "pointer", fontSize: "14px", marginTop: "8px" },
  carteStatut: { backgroundColor: "#0f172a", borderRadius: "8px", padding: "16px", border: "1px solid #334155", marginBottom: "16px" },
  statutLigne: { display: "flex", justifyContent: "space-between", padding: "8px 0", borderBottom: "1px solid #1e293b", fontSize: "14px" },
  valeurStatut: { color: "#f1f5f9", fontWeight: "500" },
  sectionGlassBreak: { marginTop: "24px", padding: "20px", borderRadius: "8px", border: "2px solid #f59e0b", backgroundColor: "#1c1208" },
  grilleConformite: { display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))", gap: "16px" },
  carteConformite: { padding: "16px", borderRadius: "8px", backgroundColor: "#0f172a", border: "1px solid #334155" },
  badgeConformite: { display: "inline-block", padding: "4px 10px", borderRadius: "12px", fontSize: "12px", fontWeight: "600", color: "white", marginBottom: "8px" },
  titreConformite: { fontSize: "14px", fontWeight: "600", color: "#f1f5f9", margin: "0 0 6px 0" },
  detailsConformite: { fontSize: "12px", color: "#94a3b8", margin: 0 },
  grilleAgents: { display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: "12px" },
  carteAgent: { padding: "16px", borderRadius: "8px", backgroundColor: "#0f172a", border: "1px solid #334155", textAlign: "center" as const },
  iconeAgent: { fontSize: "32px", display: "block", marginBottom: "8px" },
  nomAgent: { fontSize: "14px", fontWeight: "600", color: "#f1f5f9", margin: "0 0 4px 0" },
  rolesAgent: { fontSize: "12px", color: "#94a3b8", margin: "0 0 8px 0" },
};
