/**
 * CookieVaultSection.tsx — PULSAR Vault : Cookies de session (2FA)
 *
 * Section dédiée à la gestion des cookies de session dans le coffre PULSAR.
 * Permet d'importer des cookies (JSON ou Netscape) pour contourner les
 * authentifications 2FA sur les sites tiers.
 *
 * ⚠️ AVERTISSEMENT IMPORTANT :
 * Cette méthode ne fonctionne QUE si la session est authentifiée et active
 * sur le site cible. Les cookies expirent dès que la session est fermée
 * ou que le site révoque le token de session.
 *
 * DSIO — CHU de Guyane | William MERI
 */

import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  Check,
  ClipboardCopy,
  Cookie,
  Download,
  Globe,
  Info,
  Plus,
  RefreshCw,
  Save,
  ShieldAlert,
  Trash2,
  X,
  Clock,
  CheckCircle2,
  XCircle,
  Timer,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface CookieSession {
  id: string;
  label: string;
  alias: string;
  description: string;
  domains: string[];
  cookie_count: number;
  status: "valid" | "expired" | "expiring_soon" | "session" | "empty";
  created_at: string;
  updated_at: string;
}

// ---------------------------------------------------------------------------
// Helpers API
// ---------------------------------------------------------------------------

const VAULT_HEADERS = () => ({
  "Content-Type": "application/json",
  "X-Hermes-Session-Token": (window as any).__PULSAR_SESSION_TOKEN__ ?? "",
});

async function fetchCookieSessions(): Promise<CookieSession[]> {
  const r = await fetch("/api/vault/cookies", { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return data.sessions ?? [];
}

async function addCookieSession(payload: {
  label: string;
  alias: string;
  description: string;
  cookies_json?: string;
  cookies_netscape?: string;
}): Promise<CookieSession> {
  const r = await fetch("/api/vault/cookies", {
    method: "POST",
    headers: VAULT_HEADERS(),
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return data.session;
}

async function deleteCookieSession(id: string): Promise<void> {
  const r = await fetch(`/api/vault/cookies/${id}`, {
    method: "DELETE",
    headers: VAULT_HEADERS(),
  });
  if (!r.ok) throw new Error(await r.text());
}

async function exportCookiesJson(id: string): Promise<string> {
  const r = await fetch(`/api/vault/cookies/${id}/json`, { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return JSON.stringify(data.cookies, null, 2);
}

async function exportCookiesNetscape(id: string): Promise<string> {
  const r = await fetch(`/api/vault/cookies/${id}/netscape`, { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  return r.text();
}

// ---------------------------------------------------------------------------
// Statut badge
// ---------------------------------------------------------------------------

const STATUS_CONFIG = {
  valid: {
    icon: <CheckCircle2 className="w-3.5 h-3.5" />,
    label: "Valide",
    cls: "bg-green-500/10 text-green-400 border-green-500/20",
  },
  expired: {
    icon: <XCircle className="w-3.5 h-3.5" />,
    label: "Expirée",
    cls: "bg-red-500/10 text-red-400 border-red-500/20",
  },
  expiring_soon: {
    icon: <Timer className="w-3.5 h-3.5" />,
    label: "Expire bientôt",
    cls: "bg-orange-500/10 text-orange-400 border-orange-500/20",
  },
  session: {
    icon: <Clock className="w-3.5 h-3.5" />,
    label: "Session (sans expiration)",
    cls: "bg-blue-500/10 text-blue-400 border-blue-500/20",
  },
  empty: {
    icon: <AlertTriangle className="w-3.5 h-3.5" />,
    label: "Vide",
    cls: "bg-gray-500/10 text-gray-400 border-gray-500/20",
  },
};

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export function CookieVaultSection() {
  const [sessions, setSessions]       = useState<CookieSession[]>([]);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState<string | null>(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [importMode, setImportMode]   = useState<"json" | "netscape">("json");
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [exportingId, setExportingId] = useState<string | null>(null);
  const [copiedId, setCopiedId]       = useState<string | null>(null);

  // Formulaire d'ajout
  const [form, setForm] = useState({
    label: "",
    alias: "",
    description: "",
    cookies_json: "",
    cookies_netscape: "",
  });
  const [formError, setFormError]   = useState<string | null>(null);
  const [formLoading, setFormLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setSessions(await fetchCookieSessions());
    } catch (e: any) {
      setError(e.message ?? "Erreur de chargement");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // --- Ajout ---
  const handleAdd = async () => {
    setFormError(null);
    if (!form.label.trim()) {
      setFormError("Le nom est obligatoire.");
      return;
    }
    const hasJson      = form.cookies_json.trim().length > 0;
    const hasNetscape  = form.cookies_netscape.trim().length > 0;
    if (!hasJson && !hasNetscape) {
      setFormError("Collez vos cookies au format JSON ou Netscape.");
      return;
    }
    setFormLoading(true);
    try {
      await addCookieSession({
        label:            form.label,
        alias:            form.alias,
        description:      form.description,
        cookies_json:     hasJson     ? form.cookies_json     : undefined,
        cookies_netscape: hasNetscape ? form.cookies_netscape : undefined,
      });
      setForm({ label: "", alias: "", description: "", cookies_json: "", cookies_netscape: "" });
      setShowAddForm(false);
      await load();
    } catch (e: any) {
      setFormError(e.message ?? "Erreur lors de l'ajout");
    } finally {
      setFormLoading(false);
    }
  };

  // --- Export ---
  const handleExport = async (id: string, format: "json" | "netscape") => {
    setExportingId(id + format);
    try {
      const content = format === "json"
        ? await exportCookiesJson(id)
        : await exportCookiesNetscape(id);
      const blob = new Blob([content], {
        type: format === "json" ? "application/json" : "text/plain",
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = format === "json" ? `cookies_${id}.json` : `cookies_${id}.txt`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e: any) {
      alert("Erreur export : " + (e.message ?? ""));
    } finally {
      setExportingId(null);
    }
  };

  // --- Copie alias ---
  const handleCopyAlias = async (alias: string, id: string) => {
    await navigator.clipboard.writeText(`{{vault:${alias}}}`);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  // --- Suppression ---
  const handleDelete = async (id: string) => {
    try {
      await deleteCookieSession(id);
      setConfirmDeleteId(null);
      await load();
    } catch (e: any) {
      alert("Erreur suppression : " + (e.message ?? ""));
    }
  };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------

  return (
    <div className="space-y-4">

      {/* ================================================================
          AVERTISSEMENT PRINCIPAL — session active requise
          ================================================================ */}
      <div className="rounded-xl border border-orange-500/30 bg-orange-500/5 p-4">
        <div className="flex items-start gap-3">
          <ShieldAlert className="w-5 h-5 text-orange-400 mt-0.5 shrink-0" />
          <div className="space-y-2">
            <p className="text-sm font-semibold text-orange-400">
              Session authentifiée requise
            </p>
            <p className="text-xs text-muted-foreground leading-relaxed">
              Cette méthode d'authentification par cookies{" "}
              <strong className="text-foreground">ne fonctionne que si votre session est actuellement authentifiée et active</strong>{" "}
              sur le site cible. Les cookies de session sont révoqués dès que :
            </p>
            <ul className="text-xs text-muted-foreground space-y-1 ml-3 list-disc">
              <li>Vous vous déconnectez du site (logout)</li>
              <li>La session expire côté serveur (timeout)</li>
              <li>Le site détecte une activité suspecte (changement d'IP, user-agent)</li>
              <li>Le token 2FA est invalidé par une nouvelle connexion</li>
            </ul>
            <p className="text-xs text-muted-foreground leading-relaxed">
              <strong className="text-foreground">Procédure recommandée :</strong>{" "}
              Connectez-vous manuellement au site (y compris le 2FA), exportez les cookies
              avec l'extension{" "}
              <span className="font-mono text-xs bg-background/50 px-1 rounded">Cookie-Editor</span>{" "}
              ou{" "}
              <span className="font-mono text-xs bg-background/50 px-1 rounded">EditThisCookie</span>,
              puis importez-les ici. L'agent browser utilisera ces cookies pour agir
              en votre nom sans repasser par le 2FA — tant que la session reste active.
            </p>
          </div>
        </div>
      </div>

      {/* En-tête + bouton ajout */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Cookie className="w-4 h-4 text-muted-foreground" />
          <span className="text-sm font-medium">
            Sessions cookies stockées{" "}
            <span className="text-muted-foreground">({sessions.length})</span>
          </span>
        </div>
        <button
          onClick={() => setShowAddForm(!showAddForm)}
          className="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-3.5 h-3.5" />
          Importer des cookies
        </button>
      </div>

      {/* Formulaire d'import */}
      {showAddForm && (
        <div className="rounded-xl border border-border bg-card p-5 space-y-4">
          <h3 className="font-medium flex items-center gap-2 text-sm">
            <Cookie className="w-4 h-4" />
            Importer une session cookies
          </h3>

          {/* Avertissement inline dans le formulaire */}
          <div className="rounded-lg border border-orange-500/20 bg-orange-500/5 px-3 py-2.5 flex items-start gap-2">
            <Info className="w-3.5 h-3.5 text-orange-400 mt-0.5 shrink-0" />
            <p className="text-xs text-muted-foreground">
              Assurez-vous d'être <strong className="text-orange-400">connecté et authentifié</strong> sur le site
              avant d'exporter vos cookies. Une session expirée ou déconnectée ne fonctionnera pas.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">Nom *</label>
              <input
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="ex: GitHub Session, Portail CHU"
                value={form.label}
                onChange={e => setForm(f => ({ ...f, label: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">
                Alias <span className="text-muted-foreground/60">(pour {`{{vault:alias}}`})</span>
              </label>
              <input
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="github_session (généré auto si vide)"
                value={form.alias}
                onChange={e => setForm(f => ({ ...f, alias: e.target.value }))}
              />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-muted-foreground">Description</label>
            <input
              className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
              placeholder="ex: Compte admin portail, session 2FA active"
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
            />
          </div>

          {/* Sélecteur de format */}
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Format d'import</label>
            <div className="flex gap-2">
              <button
                onClick={() => setImportMode("json")}
                className={cn(
                  "flex-1 py-2 text-xs rounded-lg border transition-colors",
                  importMode === "json"
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border hover:bg-accent text-muted-foreground"
                )}
              >
                JSON <span className="text-muted-foreground/60">(EditThisCookie, Chrome DevTools)</span>
              </button>
              <button
                onClick={() => setImportMode("netscape")}
                className={cn(
                  "flex-1 py-2 text-xs rounded-lg border transition-colors",
                  importMode === "netscape"
                    ? "border-primary bg-primary/10 text-primary"
                    : "border-border hover:bg-accent text-muted-foreground"
                )}
              >
                Netscape <span className="text-muted-foreground/60">(cookies.txt, wget, curl)</span>
              </button>
            </div>
          </div>

          {/* Zone de coller */}
          {importMode === "json" ? (
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">
                Cookies JSON *{" "}
                <span className="text-muted-foreground/60">
                  (copiez depuis EditThisCookie → Export ou Chrome DevTools → Application → Cookies)
                </span>
              </label>
              <textarea
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-xs font-mono focus:outline-none focus:ring-1 focus:ring-primary resize-none"
                placeholder={`[\n  {\n    "name": "session_token",\n    "value": "abc123...",\n    "domain": "example.com",\n    "path": "/",\n    "expires": 1735689600,\n    "httpOnly": true,\n    "secure": true\n  }\n]`}
                rows={8}
                value={form.cookies_json}
                onChange={e => setForm(f => ({ ...f, cookies_json: e.target.value }))}
              />
            </div>
          ) : (
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">
                Cookies Netscape *{" "}
                <span className="text-muted-foreground/60">
                  (format cookies.txt — exporté par Cookie-Editor, wget, curl --cookie-jar)
                </span>
              </label>
              <textarea
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-xs font-mono focus:outline-none focus:ring-1 focus:ring-primary resize-none"
                placeholder={`# Netscape HTTP Cookie File\nexample.com\tFALSE\t/\tTRUE\t1735689600\tsession_token\tabc123...`}
                rows={8}
                value={form.cookies_netscape}
                onChange={e => setForm(f => ({ ...f, cookies_netscape: e.target.value }))}
              />
            </div>
          )}

          {formError && (
            <p className="text-xs text-destructive flex items-center gap-1.5">
              <AlertTriangle className="w-3.5 h-3.5" />
              {formError}
            </p>
          )}

          <div className="flex gap-2 justify-end">
            <button
              onClick={() => { setShowAddForm(false); setFormError(null); }}
              className="px-4 py-2 text-sm rounded-lg border border-border hover:bg-accent transition-colors"
            >
              Annuler
            </button>
            <button
              onClick={handleAdd}
              disabled={formLoading}
              className="flex items-center gap-2 px-4 py-2 text-sm rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50 transition-colors"
            >
              {formLoading ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Save className="w-3.5 h-3.5" />}
              Chiffrer et enregistrer
            </button>
          </div>
        </div>
      )}

      {/* Liste des sessions */}
      {loading ? (
        <div className="flex items-center justify-center py-8 text-muted-foreground gap-2 text-sm">
          <RefreshCw className="w-4 h-4 animate-spin" />
          Chargement…
        </div>
      ) : error ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/10 p-4 text-sm text-destructive">
          {error}
        </div>
      ) : sessions.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border p-10 text-center text-muted-foreground">
          <Cookie className="w-8 h-8 mx-auto mb-3 opacity-30" />
          <p className="font-medium text-sm">Aucune session cookies stockée</p>
          <p className="text-xs mt-1">
            Importez vos cookies après vous être connecté (y compris 2FA) sur le site cible.
          </p>
        </div>
      ) : (
        <div className="rounded-xl border border-border overflow-hidden">
          <div className="divide-y divide-border">
            {sessions.map(sess => {
              const statusCfg = STATUS_CONFIG[sess.status] ?? STATUS_CONFIG.session;
              const isConfirmingDelete = confirmDeleteId === sess.id;
              const isCopied = copiedId === sess.id;

              return (
                <div key={sess.id} className="p-4 hover:bg-accent/10 transition-colors">
                  <div className="flex items-start gap-3">
                    <Cookie className="w-4 h-4 text-amber-400 mt-0.5 shrink-0" />

                    <div className="flex-1 min-w-0 space-y-1.5">
                      {/* Ligne 1 : nom + statut */}
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-medium text-sm">{sess.label}</span>
                        <span className={cn(
                          "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs border",
                          statusCfg.cls
                        )}>
                          {statusCfg.icon}
                          {statusCfg.label}
                        </span>
                        {sess.status === "expired" && (
                          <span className="text-xs text-red-400 font-medium">
                            ⚠ Session expirée — à renouveler
                          </span>
                        )}
                        {sess.status === "expiring_soon" && (
                          <span className="text-xs text-orange-400 font-medium">
                            ⚠ Expire dans moins de 7 jours
                          </span>
                        )}
                      </div>

                      {/* Ligne 2 : description */}
                      {sess.description && (
                        <p className="text-xs text-muted-foreground">{sess.description}</p>
                      )}

                      {/* Ligne 3 : alias + domaines + compteur */}
                      <div className="flex items-center gap-3 flex-wrap">
                        {sess.alias && (
                          <code className="text-xs font-mono text-muted-foreground bg-muted/50 px-1.5 py-0.5 rounded">
                            {`{{vault:${sess.alias}}}`}
                          </code>
                        )}
                        {sess.domains.length > 0 && (
                          <div className="flex items-center gap-1 text-xs text-muted-foreground">
                            <Globe className="w-3 h-3" />
                            {sess.domains.slice(0, 3).join(", ")}
                            {sess.domains.length > 3 && ` +${sess.domains.length - 3}`}
                          </div>
                        )}
                        <span className="text-xs text-muted-foreground">
                          {sess.cookie_count} cookie{sess.cookie_count !== 1 ? "s" : ""}
                        </span>
                      </div>

                      {/* Avertissement inline si session expirée */}
                      {(sess.status === "expired") && (
                        <div className="rounded-lg border border-red-500/20 bg-red-500/5 px-3 py-2 flex items-start gap-2 mt-1">
                          <XCircle className="w-3.5 h-3.5 text-red-400 mt-0.5 shrink-0" />
                          <p className="text-xs text-muted-foreground">
                            Cette session est <strong className="text-red-400">expirée</strong>.
                            Reconnectez-vous sur le site, exportez de nouveaux cookies et mettez à jour cette entrée.
                          </p>
                        </div>
                      )}
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-1 shrink-0">
                      {/* Copier alias */}
                      {sess.alias && (
                        <button
                          onClick={() => handleCopyAlias(sess.alias, sess.id)}
                          title={`Copier {{vault:${sess.alias}}}`}
                          className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
                        >
                          {isCopied
                            ? <Check className="w-3.5 h-3.5 text-green-400" />
                            : <ClipboardCopy className="w-3.5 h-3.5" />
                          }
                        </button>
                      )}

                      {/* Export JSON */}
                      <button
                        onClick={() => handleExport(sess.id, "json")}
                        disabled={exportingId === sess.id + "json"}
                        title="Exporter en JSON"
                        className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
                      >
                        {exportingId === sess.id + "json"
                          ? <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                          : <Download className="w-3.5 h-3.5" />
                        }
                      </button>

                      {/* Supprimer */}
                      {isConfirmingDelete ? (
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleDelete(sess.id)}
                            className="px-2 py-1 text-xs rounded bg-destructive text-destructive-foreground hover:bg-destructive/90"
                          >
                            Confirmer
                          </button>
                          <button
                            onClick={() => setConfirmDeleteId(null)}
                            className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground"
                          >
                            <X className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      ) : (
                        <button
                          onClick={() => setConfirmDeleteId(sess.id)}
                          title="Supprimer"
                          className="p-1.5 rounded-lg hover:bg-destructive/10 text-muted-foreground hover:text-destructive transition-colors"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Note de bas de section */}
      <div className="rounded-lg border border-border bg-muted/20 px-4 py-3">
        <p className="text-xs text-muted-foreground leading-relaxed">
          <strong className="text-foreground">Comment exporter vos cookies :</strong>{" "}
          installez l'extension{" "}
          <span className="font-mono text-xs bg-background/50 px-1 rounded">Cookie-Editor</span>{" "}
          (Chrome/Firefox), connectez-vous sur le site cible (2FA inclus), cliquez sur l'extension
          → <em>Export</em> → <em>Export as JSON</em>, puis collez le résultat ici.
          Les cookies sont immédiatement chiffrés dans{" "}
          <span className="font-mono text-xs bg-background/50 px-1 rounded">~/.pulsar/vault_cookies.enc</span>.
        </p>
      </div>
    </div>
  );
}
