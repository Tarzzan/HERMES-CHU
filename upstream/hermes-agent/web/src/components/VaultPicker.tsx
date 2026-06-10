/**
 * VaultPicker.tsx — PULSAR Vault Picker
 *
 * Widget compact affiché dans la barre de saisie du chat.
 * Permet à l'utilisateur de cliquer sur un credential stocké dans le Vault
 * pour insérer {{vault:alias}} dans le message — sans jamais taper la valeur en clair.
 *
 * Usage dans ChatInput :
 *   <VaultPicker onInsert={(placeholder) => appendToInput(placeholder)} />
 *
 * DSIO — CHU de Guyane | William MERI
 */

import React, { useCallback, useEffect, useRef, useState } from "react";
import {
  Check,
  ChevronDown,
  KeyRound,
  Lock,
  Shield,
  ShieldCheck,
  Terminal,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface VaultAlias {
  id: string;
  alias: string;
  label: string;
  type: string;
  type_label: string;
  placeholder: string;
}

// ---------------------------------------------------------------------------
// Icônes par type (compact)
// ---------------------------------------------------------------------------

const TYPE_ICONS: Record<string, React.ReactElement> = {
  api_key:     <KeyRound className="w-3.5 h-3.5 text-blue-400" />,
  token:       <Shield className="w-3.5 h-3.5 text-purple-400" />,
  ssh_key:     <Terminal className="w-3.5 h-3.5 text-green-400" />,
  password:    <Lock className="w-3.5 h-3.5 text-orange-400" />,
  certificate: <ShieldCheck className="w-3.5 h-3.5 text-teal-400" />,
  custom:      <KeyRound className="w-3.5 h-3.5 text-gray-400" />,
};

// ---------------------------------------------------------------------------
// Fetch aliases
// ---------------------------------------------------------------------------

async function fetchAliases(): Promise<VaultAlias[]> {
  try {
    const headers: Record<string, string> = {};
    const token = (window as any).__PULSAR_SESSION_TOKEN__;
    if (token) headers["X-Hermes-Session-Token"] = token;
    const r = await fetch("/api/vault/aliases", { headers });
    if (!r.ok) return [];
    const data = await r.json();
    return data.aliases ?? [];
  } catch {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Composant VaultPicker
// ---------------------------------------------------------------------------

interface VaultPickerProps {
  /** Callback appelé quand l'utilisateur clique sur un alias — reçoit {{vault:alias}} */
  onInsert: (placeholder: string) => void;
  /** Classe CSS additionnelle */
  className?: string;
}

export function VaultPicker({ onInsert, className }: VaultPickerProps) {
  const [open, setOpen]       = useState(false);
  const [aliases, setAliases] = useState<VaultAlias[]>([]);
  const [loading, setLoading] = useState(false);
  const [inserted, setInserted] = useState<string | null>(null);
  const [search, setSearch]   = useState("");
  const ref = useRef<HTMLDivElement>(null);

  // Charger les aliases à l'ouverture
  useEffect(() => {
    if (!open) return;
    setLoading(true);
    fetchAliases().then(a => {
      setAliases(a);
      setLoading(false);
    });
  }, [open]);

  // Fermer au clic extérieur
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
        setSearch("");
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const handleInsert = useCallback((alias: VaultAlias) => {
    onInsert(alias.placeholder);
    setInserted(alias.id);
    setTimeout(() => {
      setInserted(null);
      setOpen(false);
      setSearch("");
    }, 800);
  }, [onInsert]);

  const filtered = aliases.filter(a =>
    a.label.toLowerCase().includes(search.toLowerCase()) ||
    a.alias.toLowerCase().includes(search.toLowerCase()) ||
    a.type_label.toLowerCase().includes(search.toLowerCase())
  );

  // Ne pas afficher si le vault est vide
  if (!open && aliases.length === 0 && !loading) {
    // Pré-charger silencieusement pour savoir si le vault a des entrées
    // (on ne bloque pas le rendu)
  }

  return (
    <div ref={ref} className={cn("relative", className)}>
      {/* Bouton déclencheur */}
      <button
        type="button"
        onClick={() => setOpen(!open)}
        title="Insérer un credential du Vault"
        className={cn(
          "flex items-center gap-1 px-2 py-1.5 rounded-lg text-xs transition-colors",
          "text-muted-foreground hover:text-foreground hover:bg-accent",
          open && "bg-accent text-foreground"
        )}
      >
        <Lock className="w-3.5 h-3.5" />
        <span className="hidden sm:inline">Vault</span>
        <ChevronDown className={cn("w-3 h-3 transition-transform", open && "rotate-180")} />
      </button>

      {/* Dropdown */}
      {open && (
        <div className={cn(
          "absolute bottom-full mb-2 left-0 z-50",
          "w-72 rounded-xl border border-border bg-popover shadow-xl",
          "overflow-hidden"
        )}>
          {/* En-tête */}
          <div className="flex items-center justify-between px-3 py-2.5 border-b border-border bg-muted/30">
            <div className="flex items-center gap-2">
              <Lock className="w-3.5 h-3.5 text-primary" />
              <span className="text-xs font-semibold">PULSAR Vault</span>
            </div>
            <button
              onClick={() => { setOpen(false); setSearch(""); }}
              className="p-0.5 rounded hover:bg-accent text-muted-foreground"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Recherche */}
          {aliases.length > 4 && (
            <div className="px-3 py-2 border-b border-border">
              <input
                autoFocus
                className="w-full bg-background rounded-lg border border-border px-2.5 py-1.5 text-xs focus:outline-none focus:ring-1 focus:ring-primary"
                placeholder="Rechercher un credential…"
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
            </div>
          )}

          {/* Liste */}
          <div className="max-h-56 overflow-y-auto">
            {loading ? (
              <div className="flex items-center justify-center py-6 text-xs text-muted-foreground gap-2">
                <div className="w-3 h-3 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                Chargement…
              </div>
            ) : filtered.length === 0 ? (
              <div className="py-6 text-center text-xs text-muted-foreground">
                {aliases.length === 0
                  ? "Aucun credential dans le Vault."
                  : "Aucun résultat."}
              </div>
            ) : (
              filtered.map(alias => (
                <button
                  key={alias.id}
                  type="button"
                  onClick={() => handleInsert(alias)}
                  className={cn(
                    "w-full flex items-center gap-3 px-3 py-2.5 text-left",
                    "hover:bg-accent transition-colors",
                    inserted === alias.id && "bg-green-500/10"
                  )}
                >
                  <div className="shrink-0">
                    {TYPE_ICONS[alias.type] ?? <KeyRound className="w-3.5 h-3.5 text-muted-foreground" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium truncate">{alias.label}</p>
                    <p className="text-xs text-muted-foreground font-mono truncate">
                      {`{{vault:${alias.alias}}}`}
                    </p>
                  </div>
                  {inserted === alias.id && (
                    <Check className="w-3.5 h-3.5 text-green-400 shrink-0" />
                  )}
                </button>
              ))
            )}
          </div>

          {/* Pied */}
          <div className="px-3 py-2 border-t border-border bg-muted/20">
            <p className="text-xs text-muted-foreground text-center">
              Cliquez pour insérer{" "}
              <code className="font-mono text-xs bg-background/50 px-1 rounded">
                {`{{vault:alias}}`}
              </code>{" "}
              dans le message
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
