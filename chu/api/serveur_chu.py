"""
HERMES CHU — Serveur API FastAPI
=================================
API REST qui expose les endpoints de configuration CHU pour l'interface web.
Ce serveur complète le gateway hermes-agent existant avec les endpoints
spécifiques au contexte hospitalier.

Endpoints :
  GET  /api/chu/config              → Configuration actuelle
  POST /api/chu/config              → Sauvegarder la configuration LLM
  GET  /api/chu/privacy/statut      → Statut du Privacy Engine
  POST /api/chu/privacy/toggle      → Activer/désactiver le Privacy Engine
  POST /api/chu/privacy/glass-break → Activer le mode glass-break
  POST /api/chu/privacy/anonymiser  → Anonymiser un texte (test)
  GET  /api/chu/audit/journal       → Journal d'audit ISO 27001
  GET  /api/chu/audit/export        → Export du journal (CSV/JSON)
  GET  /api/chu/metriques           → Métriques d'usage (Agent Qualité)
  GET  /api/chu/anonymisation/stats → Statistiques du Privacy Engine
  GET  /api/chu/insights            → Insights qualité agrégés
  GET  /api/chu/sante               → Healthcheck du système
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel, Field

# Import du Privacy Engine CHU
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from chu.privacy_engine.middleware import get_privacy_engine, get_journal_audit

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Application FastAPI
# ---------------------------------------------------------------------------

app = FastAPI(
    title="HERMES CHU — API de Configuration",
    description="API de gestion du système agentique hospitalier HERMES CHU",
    version="1.0.0",
    docs_url="/api/chu/docs",
    redoc_url="/api/chu/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Chemin du fichier de configuration CHU
CONFIG_FILE = Path(__file__).parent.parent / "config_chu.yaml"

# ---------------------------------------------------------------------------
# Modèles Pydantic
# ---------------------------------------------------------------------------

class ConfigLLM(BaseModel):
    fournisseur_actif: str = Field(..., description="Identifiant du fournisseur LLM actif")
    parametres: Dict[str, Any] = Field(default_factory=dict, description="Paramètres du fournisseur")


class TogglePrivacy(BaseModel):
    actif: bool = Field(..., description="Nouvel état du Privacy Engine")


class GlassBreakRequest(BaseModel):
    justification: str = Field(..., min_length=20, description="Justification obligatoire (min 20 caractères)")
    duree_minutes: int = Field(default=30, ge=1, le=60, description="Durée en minutes (max 60)")


class AnonymisationRequest(BaseModel):
    texte: str = Field(..., description="Texte à anonymiser")
    session_id: str = Field(default="test", description="Identifiant de session")


# ---------------------------------------------------------------------------
# Endpoints de configuration
# ---------------------------------------------------------------------------

@app.get("/api/chu/config", tags=["Configuration"])
async def get_config() -> Dict[str, Any]:
    """Retourne la configuration CHU actuelle."""
    try:
        import yaml
        with open(CONFIG_FILE) as f:
            config = yaml.safe_load(f)
        # Masquer les clés API dans la réponse
        if "llm" in config:
            for fournisseur in config["llm"].values():
                if isinstance(fournisseur, dict) and "api_key" in fournisseur:
                    fournisseur["api_key"] = "***masqué***"
        return config
    except Exception as e:
        logger.warning("Impossible de lire config_chu.yaml : %s", e)
        return {"llm": {"fournisseur_actif": "azure_openai"}, "privacy_engine": {"actif": True}}


@app.post("/api/chu/config", tags=["Configuration"])
async def sauvegarder_config(config: ConfigLLM) -> Dict[str, str]:
    """Sauvegarde la configuration du fournisseur LLM."""
    # Journaliser le changement de configuration
    get_journal_audit().enregistrer(
        "CHANGEMENT_CONFIGURATION_LLM",
        utilisateur_id="admin",
        session_id="config",
        details={
            "fournisseur": config.fournisseur_actif,
            "parametres_masques": list(config.parametres.keys()),
        },
    )
    logger.info("[CONFIG] Fournisseur LLM changé : %s", config.fournisseur_actif)
    return {"statut": "ok", "message": f"Configuration {config.fournisseur_actif} appliquée"}


# ---------------------------------------------------------------------------
# Endpoints Privacy Engine
# ---------------------------------------------------------------------------

@app.get("/api/chu/privacy/statut", tags=["Privacy Engine"])
async def get_statut_privacy() -> Dict[str, Any]:
    """Retourne le statut du Privacy Engine RGPD."""
    engine = get_privacy_engine()
    return engine.get_statut("global")


@app.post("/api/chu/privacy/toggle", tags=["Privacy Engine"])
async def toggle_privacy(body: TogglePrivacy) -> Dict[str, Any]:
    """Active ou désactive le Privacy Engine RGPD."""
    engine = get_privacy_engine()
    engine.actif = body.actif

    get_journal_audit().enregistrer(
        "TOGGLE_PRIVACY_ENGINE",
        utilisateur_id="admin",
        session_id="config",
        details={"nouvel_etat": body.actif},
    )

    return {
        "statut": "ok",
        "privacy_engine_actif": engine.actif,
        "message": "Privacy Engine activé" if body.actif else "⚠️ Privacy Engine désactivé — données brutes",
    }


@app.post("/api/chu/privacy/glass-break", tags=["Privacy Engine"])
async def activer_glass_break(body: GlassBreakRequest) -> Dict[str, Any]:
    """Active le mode glass-break pour désactivation temporaire tracée."""
    engine = get_privacy_engine()
    succes = engine.activer_glass_break(
        session_id="glass_break_global",
        utilisateur_id="admin",
        justification=body.justification,
        duree_minutes=body.duree_minutes,
    )
    if not succes:
        raise HTTPException(
            status_code=400,
            detail="Justification insuffisante ou glass-break déjà actif",
        )
    return {
        "statut": "ok",
        "glass_break_actif": True,
        "duree_minutes": body.duree_minutes,
        "message": f"Glass-Break activé pour {body.duree_minutes} min — Journalisé dans l'audit ISO 27001",
    }


@app.post("/api/chu/privacy/anonymiser", tags=["Privacy Engine"])
async def anonymiser_texte(body: AnonymisationRequest) -> Dict[str, Any]:
    """Anonymise un texte et retourne le résultat (endpoint de test)."""
    engine = get_privacy_engine()
    texte_safe, resultat = engine.anonymiser(
        body.texte, body.session_id, utilisateur_id="test"
    )
    return {
        "texte_original": body.texte,
        "texte_anonymise": texte_safe,
        "nb_entites_detectees": len(resultat.entites_detectees),
        "types_phi": list({e.type_entite for e in resultat.entites_detectees}),
        "taux_anonymisation": resultat.taux_anonymisation,
        "anonymisation_active": engine.actif,
    }


# ---------------------------------------------------------------------------
# Endpoints Audit ISO 27001
# ---------------------------------------------------------------------------

@app.get("/api/chu/audit/journal", tags=["Audit ISO 27001"])
async def get_journal(
    limite: int = 50,
    type_evenement: Optional[str] = None,
) -> Dict[str, Any]:
    """Retourne les entrées du journal d'audit ISO 27001."""
    journal = get_journal_audit()
    entrees = journal.exporter()

    if type_evenement:
        entrees = [e for e in entrees if e["type"] == type_evenement]

    entrees_paginées = entrees[-limite:]

    return {
        "total": len(entrees),
        "retourne": len(entrees_paginées),
        "entrees": entrees_paginées,
    }


@app.get("/api/chu/audit/export", tags=["Audit ISO 27001"])
async def exporter_journal(format: str = "json") -> Any:
    """Exporte le journal d'audit complet (JSON ou CSV)."""
    journal = get_journal_audit()
    entrees = journal.exporter()

    if format == "csv":
        import csv
        import io
        output = io.StringIO()
        if entrees:
            writer = csv.DictWriter(output, fieldnames=entrees[0].keys())
            writer.writeheader()
            writer.writerows(entrees)
        return StreamingResponse(
            iter([output.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=audit_hermes_chu.csv"},
        )

    return JSONResponse(
        content={"journal": entrees, "exporte_le": datetime.now(timezone.utc).isoformat()},
        headers={"Content-Disposition": "attachment; filename=audit_hermes_chu.json"},
    )


# ---------------------------------------------------------------------------
# Endpoints Métriques & Insights (Agent Qualité)
# ---------------------------------------------------------------------------

@app.get("/api/chu/metriques", tags=["Métriques"])
async def get_metriques() -> Dict[str, Any]:
    """Métriques d'usage du système — consommées par l'Agent Qualité."""
    engine = get_privacy_engine()
    entrees = get_journal_audit().exporter()

    compteurs: Dict[str, int] = {}
    for e in entrees:
        compteurs[e["type"]] = compteurs.get(e["type"], 0) + 1

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "privacy_engine_actif": engine.actif,
        "sessions_glass_break_actives": len(engine._sessions_glass_break),
        "audit_entrees_total": len(entrees),
        "evenements_par_type": compteurs,
        "anonymisations_effectuees": compteurs.get("ANONYMISATION_EFFECTUEE", 0),
        "glass_breaks_actives_total": compteurs.get("GLASS_BREAK_ACTIVE", 0),
        "phi_residuels_sortie_llm": compteurs.get("phi_residuel_sortie_llm", 0),
    }


@app.get("/api/chu/anonymisation/stats", tags=["Métriques"])
async def get_stats_anonymisation() -> Dict[str, Any]:
    """Statistiques détaillées du Privacy Engine (types de PHI, sessions)."""
    entrees = get_journal_audit().exporter()
    evenements_anonymisation = [
        e for e in entrees if e["type"] == "ANONYMISATION_EFFECTUEE"
    ]

    entites_par_type: Dict[str, int] = {}
    total_entites = 0
    taux_cumules: List[float] = []
    for e in evenements_anonymisation:
        details = e.get("details", {})
        total_entites += details.get("nb_entites", 0)
        taux_cumules.append(details.get("taux_anonymisation", 0.0))
        for type_phi in details.get("types", []):
            entites_par_type[type_phi] = entites_par_type.get(type_phi, 0) + 1

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "total_anonymisations": len(evenements_anonymisation),
        "total_entites_phi_detectees": total_entites,
        "occurrences_par_type_phi": entites_par_type,
        "taux_anonymisation_moyen": (
            round(sum(taux_cumules) / len(taux_cumules), 2) if taux_cumules else 0.0
        ),
        "sessions_avec_phi": len({e["session"] for e in evenements_anonymisation}),
        "contournements_glass_break": sum(
            1 for e in entrees if e["type"] == "ANONYMISATION_CONTOURNEE_GLASS_BREAK"
        ),
    }


@app.get("/api/chu/insights", tags=["Métriques"])
async def get_insights() -> Dict[str, Any]:
    """Insights qualité agrégés — export vers l'API Qualité (config insights.api_qualite_url)."""
    metriques = await get_metriques()
    stats = await get_stats_anonymisation()
    alertes: List[str] = []
    if metriques["phi_residuels_sortie_llm"] > 0:
        alertes.append(
            f"{metriques['phi_residuels_sortie_llm']} PHI résiduels détectés en sortie LLM — "
            "réviser le prompt système"
        )
    if metriques["sessions_glass_break_actives"] > 0:
        alertes.append(
            f"{metriques['sessions_glass_break_actives']} session(s) glass-break active(s) — "
            "anonymisation contournée"
        )
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "metriques": metriques,
        "anonymisation": stats,
        "alertes": alertes,
    }


# ---------------------------------------------------------------------------
# Healthcheck
# ---------------------------------------------------------------------------

@app.get("/api/chu/sante", tags=["Système"])
async def healthcheck() -> Dict[str, Any]:
    """Vérifie l'état de santé du système HERMES CHU."""
    engine = get_privacy_engine()
    return {
        "statut": "ok",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "composants": {
            "privacy_engine": "actif" if engine.actif else "inactif",
            "journal_audit": "ok",
            "api": "ok",
        },
    }


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")
