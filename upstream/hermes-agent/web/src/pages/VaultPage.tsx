/**
 * VaultPage.tsx — PULSAR Vault
 * Coffre de credentials sécurisé : API keys, tokens, clés SSH, mots de passe.
 *
 * Fonctionnalités :
 *  - Ajout / modification / suppression de credentials
 *  - Affichage masqué par défaut, révélation à la demande (rate-limitée)
 *  - Copie sécurisée en un clic
 *  - Copie de la variable {{vault:alias}} pour injection dans le chat
 *  - Journal d'audit des accès
 *  - Catégorisation par type (API key, SSH, token, mot de passe…)
 *
 * DSIO — CHU de Guyane | William MERI
 */

import { useCallback, useEffect, useLayoutEffect, useState } from "react";
import {
  AlertTriangle,
  Check,
  ChevronDown,
  ChevronRight,
  ClipboardCopy,
  Eye,
  EyeOff,
  KeyRound,
  Lock,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  Shield,
  ShieldCheck,
  Trash2,
  X,
  History,
  Terminal,
} from "lucide-react";
import { api } from "@/lib/api";
import { useI18n } from "@/i18n";
import { usePageHeader } from "@/contexts/usePageHeader";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface VaultCredential {
  id: string;
  label: string;
  alias: string;
  type: string;
  type_label: string;
  description: string;
  created_at: string;
  updated_at: string;
  has_value: boolean;
}

interface AuditEntry {
  ts: string;
  action: string;
  id: string;
  label: string;
  ip: string;
}

interface VaultStatus {
  available: boolean;
  initialized: boolean;
  count: number;
  key_path?: string;
  data_path?: string;
  reason?: string;
}

// ---------------------------------------------------------------------------
// Helpers API
// ---------------------------------------------------------------------------

const VAULT_HEADERS = () => ({
  "Content-Type": "application/json",
  "X-Hermes-Session-Token": (window as any).__PULSAR_SESSION_TOKEN__ ?? "",
});

async function fetchVaultList(): Promise<{ credentials: VaultCredential[]; types: Record<string, string> }> {
  const r = await fetch("/api/vault", { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function fetchVaultStatus(): Promise<VaultStatus> {
  const r = await fetch("/api/vault/status", { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function fetchVaultAudit(): Promise<{ entries: AuditEntry[] }> {
  const r = await fetch("/api/vault/audit?limit=30", { headers: VAULT_HEADERS() });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}

async function addCredential(payload: {
  label: string; value: string; type: string; alias: string; description: string;
}): Promise<VaultCredential> {
  const r = await fetch("/api/vault", {
    method: "POST",
    headers: VAULT_HEADERS(),
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return data.credential;
}

async function updateCredential(id: string, payload: {
  label?: string; value?: string; alias?: string; description?: string;
}): Promise<VaultCredential> {
  const r = await fetch(`/api/vault/${id}`, {
    method: "PATCH",
    headers: VAULT_HEADERS(),
    body: JSON.stringify(payload),
  });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return data.credential;
}

async function deleteCredential(id: string): Promise<void> {
  const r = await fetch(`/api/vault/${id}`, {
    method: "DELETE",
    headers: VAULT_HEADERS(),
  });
  if (!r.ok) throw new Error(await r.text());
}

async function revealCredential(id: string): Promise<string> {
  const r = await fetch("/api/vault/reveal", {
    method: "POST",
    headers: VAULT_HEADERS(),
    body: JSON.stringify({ id }),
  });
  if (!r.ok) throw new Error(await r.text());
  const data = await r.json();
  return data.value;
}

// ---------------------------------------------------------------------------
// Icônes par type
// ---------------------------------------------------------------------------

const TYPE_ICONS: Record<string, JSX.Element> = {
  api_key:     <KeyRound className="w-4 h-4 text-blue-400" />,
  token:       <Shield className="w-4 h-4 text-purple-400" />,
  ssh_key:     <Terminal className="w-4 h-4 text-green-400" />,
  password:    <Lock className="w-4 h-4 text-orange-400" />,
  certificate: <ShieldCheck className="w-4 h-4 text-teal-400" />,
  custom:      <KeyRound className="w-4 h-4 text-gray-400" />,
};

const TYPE_COLORS: Record<string, string> = {
  api_key:     "bg-blue-500/10 text-blue-400 border-blue-500/20",
  token:       "bg-purple-500/10 text-purple-400 border-purple-500/20",
  ssh_key:     "bg-green-500/10 text-green-400 border-green-500/20",
  password:    "bg-orange-500/10 text-orange-400 border-orange-500/20",
  certificate: "bg-teal-500/10 text-teal-400 border-teal-500/20",
  custom:      "bg-gray-500/10 text-gray-400 border-gray-500/20",
};

const ACTION_LABELS: Record<string, string> = {
  add:     "Ajout",
  update:  "Modification",
  delete:  "Suppression",
  reveal:  "Révélation",
  resolve: "Injection agent",
};

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export function VaultPage() {
  const { t } = useI18n();
  const { setHeader } = usePageHeader();

  const [status, setStatus]           = useState<VaultStatus | null>(null);
  const [credentials, setCredentials] = useState<VaultCredential[]>([]);
  const [types, setTypes]             = useState<Record<string, string>>({});
  const [auditLog, setAuditLog]       = useState<AuditEntry[]>([]);
  const [showAudit, setShowAudit]     = useState(false);
  const [loading, setLoading]         = useState(true);
  const [error, setError]             = useState<string | null>(null);

  // Formulaire d'ajout
  const [showAddForm, setShowAddForm] = useState(false);
  const [addForm, setAddForm]         = useState({
    label: "", value: "", type: "api_key", alias: "", description: "",
  });
  const [addError, setAddError]       = useState<string | null>(null);
  const [addLoading, setAddLoading]   = useState(false);

  // Édition
  const [editingId, setEditingId]     = useState<string | null>(null);
  const [editForm, setEditForm]       = useState({ label: "", alias: "", description: "", value: "" });

  // Révélation
  const [revealedValues, setRevealedValues] = useState<Record<string, string>>({});
  const [revealLoading, setRevealLoading]   = useState<string | null>(null);

  // Copie
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Suppression
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  useLayoutEffect(() => {
    setHeader({
      title: "PULSAR Vault",
      description: "Coffre de credentials sécurisé — API keys, clés SSH, tokens",
      icon: <Lock className="w-5 h-5" />,
    });
  }, [setHeader]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [st, list] = await Promise.all([fetchVaultStatus(), fetchVaultList()]);
      setStatus(st);
      setCredentials(list.credentials);
      setTypes(list.types);
    } catch (e: any) {
      setError(e.message ?? "Erreur de chargement");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  const loadAudit = useCallback(async () => {
    try {
      const data = await fetchVaultAudit();
      setAuditLog(data.entries);
    } catch { /* silencieux */ }
  }, []);

  useEffect(() => {
    if (showAudit) loadAudit();
  }, [showAudit, loadAudit]);

  // --- Ajout ---
  const handleAdd = async () => {
    setAddError(null);
    if (!addForm.label.trim() || !addForm.value.trim()) {
      setAddError("Le nom et la valeur sont obligatoires.");
      return;
    }
    setAddLoading(true);
    try {
      await addCredential(addForm);
      setAddForm({ label: "", value: "", type: "api_key", alias: "", description: "" });
      setShowAddForm(false);
      await loadData();
    } catch (e: any) {
      setAddError(e.message ?? "Erreur lors de l'ajout");
    } finally {
      setAddLoading(false);
    }
  };

  // --- Révélation ---
  const handleReveal = async (id: string) => {
    if (revealedValues[id]) {
      // Masquer
      setRevealedValues(prev => { const n = { ...prev }; delete n[id]; return n; });
      return;
    }
    setRevealLoading(id);
    try {
      const value = await revealCredential(id);
      setRevealedValues(prev => ({ ...prev, [id]: value }));
    } catch (e: any) {
      alert("Impossible de révéler : " + (e.message ?? "Erreur"));
    } finally {
      setRevealLoading(null);
    }
  };

  // --- Copie valeur ---
  const handleCopyValue = async (id: string) => {
    let value = revealedValues[id];
    if (!value) {
      try { value = await revealCredential(id); } catch { return; }
    }
    await navigator.clipboard.writeText(value);
    setCopiedId(id + "_val");
    setTimeout(() => setCopiedId(null), 2000);
  };

  // --- Copie variable ---
  const handleCopyAlias = async (alias: string, id: string) => {
    await navigator.clipboard.writeText(`{{vault:${alias}}}`);
    setCopiedId(id + "_alias");
    setTimeout(() => setCopiedId(null), 2000);
  };

  // --- Suppression ---
  const handleDelete = async (id: string) => {
    try {
      await deleteCredential(id);
      setConfirmDeleteId(null);
      await loadData();
    } catch (e: any) {
      alert("Erreur suppression : " + (e.message ?? ""));
    }
  };

  // --- Édition ---
  const startEdit = (cred: VaultCredential) => {
    setEditingId(cred.id);
    setEditForm({ label: cred.label, alias: cred.alias, description: cred.description, value: "" });
  };

  const handleSaveEdit = async () => {
    if (!editingId) return;
    try {
      await updateCredential(editingId, {
        label: editForm.label || undefined,
        alias: editForm.alias || undefined,
        description: editForm.description || undefined,
        value: editForm.value || undefined,
      });
      setEditingId(null);
      await loadData();
    } catch (e: any) {
      alert("Erreur modification : " + (e.message ?? ""));
    }
  };

  // ---------------------------------------------------------------------------
  // Rendu
  // ---------------------------------------------------------------------------

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64 text-muted-foreground">
        <RefreshCw className="w-5 h-5 animate-spin mr-2" />
        Chargement du coffre…
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 flex gap-3">
          <AlertTriangle className="w-5 h-5 text-destructive mt-0.5 shrink-0" />
          <div>
            <p className="font-medium text-destructive">Erreur de chargement du Vault</p>
            <p className="text-sm text-muted-foreground mt-1">{error}</p>
          </div>
        </div>
      </div>
    );
  }

  // Vault indisponible (cryptography manquant)
  if (status && !status.available) {
    return (
      <div className="p-6 max-w-2xl mx-auto">
        <div className="rounded-lg border border-yellow-500/30 bg-yellow-500/10 p-5">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-yellow-500 mt-0.5 shrink-0" />
            <div>
              <p className="font-semibold text-yellow-400">PULSAR Vault indisponible</p>
              <p className="text-sm text-muted-foreground mt-1">{status.reason}</p>
              <code className="block mt-3 bg-background/50 rounded px-3 py-2 text-xs font-mono">
                pip install cryptography
              </code>
              <p className="text-xs text-muted-foreground mt-2">
                Relancez PULSAR après l'installation.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Grouper par type
  const byType: Record<string, VaultCredential[]> = {};
  for (const cred of credentials) {
    if (!byType[cred.type]) byType[cred.type] = [];
    byType[cred.type].push(cred);
  }

  return (
    <div className="p-4 md:p-6 max-w-4xl mx-auto space-y-6">

      {/* En-tête statut */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
            <Lock className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h2 className="font-semibold text-lg">PULSAR Vault</h2>
            <p className="text-sm text-muted-foreground">
              {credentials.length} credential{credentials.length !== 1 ? "s" : ""} stocké{credentials.length !== 1 ? "s" : ""} — chiffrement AES-256
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowAudit(!showAudit)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-lg border border-border hover:bg-accent transition-colors"
          >
            <History className="w-3.5 h-3.5" />
            Audit
          </button>
          <button
            onClick={() => setShowAddForm(!showAddForm)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            Ajouter
          </button>
        </div>
      </div>

      {/* Bandeau sécurité */}
      <div className="rounded-lg border border-green-500/20 bg-green-500/5 px-4 py-3 flex items-start gap-3">
        <ShieldCheck className="w-4 h-4 text-green-400 mt-0.5 shrink-0" />
        <p className="text-xs text-muted-foreground leading-relaxed">
          <span className="text-green-400 font-medium">Coffre chiffré localement.</span>{" "}
          Les valeurs sont chiffrées avec AES-256 (Fernet) dans{" "}
          <code className="font-mono text-xs bg-background/50 px-1 rounded">~/.pulsar/vault.enc</code>.
          La clé maître est dans{" "}
          <code className="font-mono text-xs bg-background/50 px-1 rounded">~/.pulsar/vault.key</code>{" "}
          (chmod 600). Utilisez <code className="font-mono text-xs bg-background/50 px-1 rounded">{`{{vault:alias}}`}</code>{" "}
          dans le chat pour injecter un credential sans le taper en clair.
        </p>
      </div>

      {/* Formulaire d'ajout */}
      {showAddForm && (
        <div className="rounded-xl border border-border bg-card p-5 space-y-4">
          <h3 className="font-medium flex items-center gap-2">
            <Plus className="w-4 h-4" />
            Nouveau credential
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">Nom *</label>
              <input
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="ex: OpenAI Production"
                value={addForm.label}
                onChange={e => setAddForm(f => ({ ...f, label: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">Type</label>
              <select
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
                value={addForm.type}
                onChange={e => setAddForm(f => ({ ...f, type: e.target.value }))}
              >
                {Object.entries(types).map(([k, v]) => (
                  <option key={k} value={k}>{v}</option>
                ))}
              </select>
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-muted-foreground">
              Valeur * <span className="text-muted-foreground/60">(sera chiffrée)</span>
            </label>
            <textarea
              className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary resize-none"
              placeholder={addForm.type === "ssh_key" ? "-----BEGIN OPENSSH PRIVATE KEY-----\n..." : "sk-..."}
              rows={addForm.type === "ssh_key" ? 5 : 2}
              value={addForm.value}
              onChange={e => setAddForm(f => ({ ...f, value: e.target.value }))}
            />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">
                Alias <span className="text-muted-foreground/60">(pour {`{{vault:alias}}`})</span>
              </label>
              <input
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="openai_prod (généré auto si vide)"
                value={addForm.alias}
                onChange={e => setAddForm(f => ({ ...f, alias: e.target.value }))}
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-muted-foreground">Description</label>
              <input
                className="w-full rounded-lg border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="Optionnel"
                value={addForm.description}
                onChange={e => setAddForm(f => ({ ...f, description: e.target.value }))}
              />
            </div>
          </div>

          {addError && (
            <p className="text-xs text-destructive flex items-center gap-1.5">
              <AlertTriangle className="w-3.5 h-3.5" />
              {addError}
            </p>
          )}

          <div className="flex gap-2 justify-end">
            <button
              onClick={() => { setShowAddForm(false); setAddError(null); }}
              className="px-4 py-2 text-sm rounded-lg border border-border hover:bg-accent transition-colors"
            >
              Annuler
            </button>
            <button
              onClick={handleAdd}
              disabled={addLoading}
              className="flex items-center gap-2 px-4 py-2 text-sm rounded-lg bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50 transition-colors"
            >
              {addLoading ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Save className="w-3.5 h-3.5" />}
              Enregistrer
            </button>
          </div>
        </div>
      )}

      {/* Liste des credentials */}
      {credentials.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border p-12 text-center text-muted-foreground">
          <Lock className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p className="font-medium">Coffre vide</p>
          <p className="text-sm mt-1">Ajoutez votre premier credential en cliquant sur « Ajouter ».</p>
        </div>
      ) : (
        <div className="space-y-3">
          {Object.entries(byType).map(([type, creds]) => (
            <div key={type} className="rounded-xl border border-border overflow-hidden">
              <div className="flex items-center gap-2 px-4 py-2.5 bg-muted/30 border-b border-border">
                {TYPE_ICONS[type] ?? <KeyRound className="w-4 h-4" />}
                <span className="text-sm font-medium">{types[type] ?? type}</span>
                <span className="ml-auto text-xs text-muted-foreground">{creds.length}</span>
              </div>
              <div className="divide-y divide-border">
                {creds.map(cred => (
                  <CredentialRow
                    key={cred.id}
                    cred={cred}
                    isEditing={editingId === cred.id}
                    editForm={editForm}
                    setEditForm={setEditForm}
                    revealedValue={revealedValues[cred.id]}
                    revealLoading={revealLoading === cred.id}
                    copiedId={copiedId}
                    confirmDeleteId={confirmDeleteId}
                    onReveal={() => handleReveal(cred.id)}
                    onCopyValue={() => handleCopyValue(cred.id)}
                    onCopyAlias={() => handleCopyAlias(cred.alias, cred.id)}
                    onEdit={() => startEdit(cred)}
                    onSaveEdit={handleSaveEdit}
                    onCancelEdit={() => setEditingId(null)}
                    onConfirmDelete={() => setConfirmDeleteId(cred.id)}
                    onDelete={() => handleDelete(cred.id)}
                    onCancelDelete={() => setConfirmDeleteId(null)}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Journal d'audit */}
      {showAudit && (
        <div className="rounded-xl border border-border overflow-hidden">
          <div className="flex items-center gap-2 px-4 py-3 bg-muted/30 border-b border-border">
            <History className="w-4 h-4 text-muted-foreground" />
            <span className="text-sm font-medium">Journal d'audit</span>
            <button onClick={loadAudit} className="ml-auto p-1 hover:text-foreground text-muted-foreground">
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
          </div>
          {auditLog.length === 0 ? (
            <p className="text-sm text-muted-foreground p-4 text-center">Aucune entrée d'audit.</p>
          ) : (
            <div className="divide-y divide-border max-h-64 overflow-y-auto">
              {auditLog.map((entry, i) => (
                <div key={i} className="flex items-center gap-3 px-4 py-2.5 text-xs">
                  <span className="text-muted-foreground font-mono shrink-0">
                    {entry.ts.replace("T", " ").replace("Z", "")}
                  </span>
                  <span className={cn(
                    "px-1.5 py-0.5 rounded font-medium shrink-0",
                    entry.action === "reveal"  ? "bg-orange-500/10 text-orange-400" :
                    entry.action === "delete"  ? "bg-red-500/10 text-red-400" :
                    entry.action === "add"     ? "bg-green-500/10 text-green-400" :
                    "bg-muted text-muted-foreground"
                  )}>
                    {ACTION_LABELS[entry.action] ?? entry.action}
                  </span>
                  <span className="truncate">{entry.label}</span>
                  <span className="ml-auto text-muted-foreground shrink-0">{entry.ip}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Composant ligne credential
// ---------------------------------------------------------------------------

interface CredentialRowProps {
  cred: VaultCredential;
  isEditing: boolean;
  editForm: { label: string; alias: string; description: string; value: string };
  setEditForm: (fn: (f: any) => any) => void;
  revealedValue?: string;
  revealLoading: boolean;
  copiedId: string | null;
  confirmDeleteId: string | null;
  onReveal: () => void;
  onCopyValue: () => void;
  onCopyAlias: () => void;
  onEdit: () => void;
  onSaveEdit: () => void;
  onCancelEdit: () => void;
  onConfirmDelete: () => void;
  onDelete: () => void;
  onCancelDelete: () => void;
}

function CredentialRow({
  cred, isEditing, editForm, setEditForm,
  revealedValue, revealLoading, copiedId, confirmDeleteId,
  onReveal, onCopyValue, onCopyAlias, onEdit, onSaveEdit, onCancelEdit,
  onConfirmDelete, onDelete, onCancelDelete,
}: CredentialRowProps) {
  const isRevealed = !!revealedValue;
  const isCopiedVal   = copiedId === cred.id + "_val";
  const isCopiedAlias = copiedId === cred.id + "_alias";
  const isConfirmingDelete = confirmDeleteId === cred.id;

  if (isEditing) {
    return (
      <div className="p-4 space-y-3 bg-accent/30">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div className="space-y-1">
            <label className="text-xs text-muted-foreground">Nom</label>
            <input
              className="w-full rounded-lg border border-border bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
              value={editForm.label}
              onChange={e => setEditForm((f: any) => ({ ...f, label: e.target.value }))}
            />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-muted-foreground">Alias</label>
            <input
              className="w-full rounded-lg border border-border bg-background px-3 py-1.5 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary"
              value={editForm.alias}
              onChange={e => setEditForm((f: any) => ({ ...f, alias: e.target.value }))}
            />
          </div>
        </div>
        <div className="space-y-1">
          <label className="text-xs text-muted-foreground">Nouvelle valeur (laisser vide pour ne pas modifier)</label>
          <input
            type="password"
            className="w-full rounded-lg border border-border bg-background px-3 py-1.5 text-sm font-mono focus:outline-none focus:ring-1 focus:ring-primary"
            placeholder="••••••••"
            value={editForm.value}
            onChange={e => setEditForm((f: any) => ({ ...f, value: e.target.value }))}
          />
        </div>
        <div className="flex gap-2 justify-end">
          <button onClick={onCancelEdit} className="px-3 py-1.5 text-xs rounded-lg border border-border hover:bg-accent">
            Annuler
          </button>
          <button onClick={onSaveEdit} className="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-lg bg-primary text-primary-foreground hover:bg-primary/90">
            <Save className="w-3 h-3" /> Enregistrer
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3 px-4 py-3 hover:bg-accent/20 transition-colors">
      {/* Icône type */}
      <div className="shrink-0">
        {TYPE_ICONS[cred.type] ?? <KeyRound className="w-4 h-4 text-muted-foreground" />}
      </div>

      {/* Infos */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="font-medium text-sm truncate">{cred.label}</span>
          {cred.description && (
            <span className="text-xs text-muted-foreground truncate hidden md:block">— {cred.description}</span>
          )}
        </div>
        <div className="flex items-center gap-2 mt-0.5">
          {cred.alias && (
            <code className="text-xs font-mono text-muted-foreground bg-muted/50 px-1.5 py-0.5 rounded">
              {`{{vault:${cred.alias}}}`}
            </code>
          )}
        </div>
      </div>

      {/* Valeur masquée / révélée */}
      <div className="shrink-0 hidden md:flex items-center gap-1.5 font-mono text-xs text-muted-foreground min-w-0 max-w-[200px]">
        {isRevealed ? (
          <span className="truncate text-foreground">{revealedValue}</span>
        ) : (
          <span>••••••••••••</span>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center gap-1 shrink-0">
        {/* Révéler / Masquer */}
        <button
          onClick={onReveal}
          disabled={revealLoading}
          title={isRevealed ? "Masquer" : "Révéler"}
          className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
        >
          {revealLoading ? (
            <RefreshCw className="w-3.5 h-3.5 animate-spin" />
          ) : isRevealed ? (
            <EyeOff className="w-3.5 h-3.5" />
          ) : (
            <Eye className="w-3.5 h-3.5" />
          )}
        </button>

        {/* Copier la valeur */}
        <button
          onClick={onCopyValue}
          title="Copier la valeur"
          className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
        >
          {isCopiedVal ? <Check className="w-3.5 h-3.5 text-green-400" /> : <ClipboardCopy className="w-3.5 h-3.5" />}
        </button>

        {/* Copier la variable */}
        {cred.alias && (
          <button
            onClick={onCopyAlias}
            title={`Copier {{vault:${cred.alias}}}`}
            className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
          >
            {isCopiedAlias ? <Check className="w-3.5 h-3.5 text-green-400" /> : <Terminal className="w-3.5 h-3.5" />}
          </button>
        )}

        {/* Éditer */}
        <button
          onClick={onEdit}
          title="Modifier"
          className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground hover:text-foreground transition-colors"
        >
          <Pencil className="w-3.5 h-3.5" />
        </button>

        {/* Supprimer */}
        {isConfirmingDelete ? (
          <div className="flex items-center gap-1">
            <button
              onClick={onDelete}
              className="px-2 py-1 text-xs rounded bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Confirmer
            </button>
            <button
              onClick={onCancelDelete}
              className="p-1.5 rounded-lg hover:bg-accent text-muted-foreground"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        ) : (
          <button
            onClick={onConfirmDelete}
            title="Supprimer"
            className="p-1.5 rounded-lg hover:bg-destructive/10 text-muted-foreground hover:text-destructive transition-colors"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
    </div>
  );
}
