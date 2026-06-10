"""
HERMES CHU — Serveur FastAPI du Privacy Engine
Microservice d'anonymisation exposé en interne au cluster Kubernetes.
"""

from __future__ import annotations

import logging
import os
from typing import Optional

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from anonymizer import PrivacyEngine, StockageRedis, StockageMemoire

logger = logging.getLogger("hermes.privacy.serveur")

app = FastAPI(
    title="HERMES CHU — Privacy Engine",
    description="Service d'anonymisation réversible des PHI. Usage interne uniquement.",
    version="1.0.0",
    docs_url="/docs",
    openapi_url="/openapi.json",
)

# Initialisation du moteur
_redis_url = os.getenv("REDIS_URL")
_stockage = StockageRedis(_redis_url) if _redis_url else StockageMemoire()
_engine = PrivacyEngine(
    stockage=_stockage,
    sel_hash=os.getenv("PRIVACY_SEL_HASH"),
    ttl_mapping_s=int(os.getenv("TTL_MAPPING_S", "3600")),
    activer_ner=os.getenv("ACTIVER_NER", "false").lower() == "true",
)


# ---------------------------------------------------------------------------
# Modèles
# ---------------------------------------------------------------------------

class RequeteAnonymisation(BaseModel):
    texte: str = Field(..., min_length=1, max_length=50_000)
    id_session: str = Field(..., description="Identifiant de session unique")


class ReponseAnonymisation(BaseModel):
    texte_anonymise: str
    nb_entites_detectees: int
    id_session: str


class RequeteRehydratation(BaseModel):
    texte: str = Field(..., min_length=1)
    id_session: str


class RequeteBasculement(BaseModel):
    id_session: str
    activer: bool
    id_utilisateur: str
    justification: str = Field(..., min_length=10, description="Justification obligatoire")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/sante", tags=["Système"])
async def sante():
    return {"statut": "opérationnel", "ner_actif": _engine.activer_ner}


@app.post("/anonymiser", response_model=ReponseAnonymisation, tags=["Anonymisation"])
async def anonymiser(requete: RequeteAnonymisation):
    """Anonymise un texte en remplaçant les PHI par des tokens."""
    texte_anonymise, mapping = await _engine.anonymize(requete.texte, requete.id_session)
    return ReponseAnonymisation(
        texte_anonymise=texte_anonymise,
        nb_entites_detectees=len(mapping),
        id_session=requete.id_session,
    )


@app.post("/rehydrater", tags=["Anonymisation"])
async def rehydrater(requete: RequeteRehydratation):
    """Restaure les valeurs originales dans un texte tokenisé."""
    texte_original = await _engine.rehydrate(requete.texte, requete.id_session)
    return {"texte_original": texte_original, "id_session": requete.id_session}


@app.delete("/sessions/{id_session}", tags=["Sessions"])
async def purger_session(id_session: str):
    """Purge le mapping d'une session (RGPD)."""
    await _engine.purger_session(id_session)
    return {"message": f"Session {id_session} purgée."}


@app.post("/basculer-mode", tags=["Administration"])
async def basculer_mode(requete: RequeteBasculement):
    """
    Active ou désactive l'anonymisation pour une session.
    Opération critique — journalisée systématiquement.
    """
    evenement = await _engine.basculer_mode(
        requete.id_session,
        requete.activer,
        requete.id_utilisateur,
        requete.justification,
    )
    return evenement


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "serveur_privacy:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8001")),
        log_level="info",
    )
