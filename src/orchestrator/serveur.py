"""
HERMES CHU — Serveur FastAPI de l'Orchestrateur
Expose l'API REST et WebSocket pour l'interface web et la gateway.
"""

from __future__ import annotations

import logging
import os
import uuid
from typing import AsyncIterator, Optional

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

# Garantit l'import quel que soit le répertoire de lancement
# (python serveur.py, uvicorn serveur:app, python -m src.orchestrator.main)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from orchestrateur_pilote import OrchestratorPilote, SessionAgent, TypeMessage

logger = logging.getLogger("hermes.serveur")

# ---------------------------------------------------------------------------
# Application FastAPI
# ---------------------------------------------------------------------------

app = FastAPI(
    title="HERMES CHU — API Orchestrateur",
    description="API de l'Agent Pilote HERMES CHU. Conformité ISO 27001 / HDS.",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# CORS (limité aux origines autorisées)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINES", "http://localhost:3000").split(","),
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)

# Singleton de l'orchestrateur
_orchestrateur: Optional[OrchestratorPilote] = None


def get_orchestrateur() -> OrchestratorPilote:
    global _orchestrateur
    if _orchestrateur is None:
        _orchestrateur = OrchestratorPilote()
    return _orchestrateur


# ---------------------------------------------------------------------------
# Modèles Pydantic
# ---------------------------------------------------------------------------

class RequeteChat(BaseModel):
    """Corps d'une requête de dialogue."""
    id_session: Optional[str] = Field(default=None, description="ID de session existante (optionnel)")
    message: str = Field(..., min_length=1, max_length=10_000, description="Message de l'utilisateur")
    id_utilisateur: str = Field(..., description="Identifiant de l'utilisateur (depuis JWT Keycloak)")
    role_utilisateur: str = Field(..., description="Rôle RBAC de l'utilisateur")
    service: str = Field(default="", description="Service hospitalier de l'utilisateur")
    anonymisation_active: bool = Field(default=True, description="Activer le SAS d'anonymisation")


class ReponseChat(BaseModel):
    """Réponse d'une requête de dialogue (non-streaming)."""
    id_session: str
    reponse: str
    nb_iterations: int
    tokens_utilises: int


class StatutSante(BaseModel):
    """Statut de santé du service."""
    statut: str
    version: str
    modele: str


# ---------------------------------------------------------------------------
# Gestion des sessions (en mémoire pour le dev — Redis en prod)
# ---------------------------------------------------------------------------

_sessions: dict[str, SessionAgent] = {}


def obtenir_ou_creer_session(
    id_session: Optional[str],
    id_utilisateur: str,
    role_utilisateur: str,
    service: str,
    anonymisation_active: bool,
) -> SessionAgent:
    if id_session and id_session in _sessions:
        return _sessions[id_session]

    session = SessionAgent(
        id_session=id_session or str(uuid.uuid4()),
        id_utilisateur=id_utilisateur,
        role_utilisateur=role_utilisateur,
        service=service,
        anonymisation_active=anonymisation_active,
    )
    _sessions[session.id_session] = session
    return session


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/sante", response_model=StatutSante, tags=["Système"])
async def sante():
    """Vérifie l'état de santé du service."""
    return StatutSante(
        statut="opérationnel",
        version="1.0.0",
        modele=os.getenv("MODEL_NAME", "Hermes-3-Llama-3.1-70B-Instruct"),
    )


@app.post("/api/v1/chat", response_model=ReponseChat, tags=["Dialogue"])
async def chat(
    requete: RequeteChat,
    orchestrateur: OrchestratorPilote = Depends(get_orchestrateur),
):
    """
    Envoie un message à l'Agent Pilote et reçoit une réponse complète.
    Pour le streaming, utiliser l'endpoint WebSocket /api/v1/ws/{id_session}.
    """
    session = obtenir_ou_creer_session(
        requete.id_session,
        requete.id_utilisateur,
        requete.role_utilisateur,
        requete.service,
        requete.anonymisation_active,
    )

    fragments = []
    async for fragment in orchestrateur.traiter_requete(session, requete.message):
        fragments.append(fragment)

    return ReponseChat(
        id_session=session.id_session,
        reponse="".join(fragments),
        nb_iterations=session.nb_iterations,
        tokens_utilises=session.tokens_utilises,
    )


@app.post("/api/v1/chat/stream", tags=["Dialogue"])
async def chat_stream(
    requete: RequeteChat,
    orchestrateur: OrchestratorPilote = Depends(get_orchestrateur),
):
    """
    Envoie un message et reçoit la réponse en streaming (Server-Sent Events).
    """
    session = obtenir_ou_creer_session(
        requete.id_session,
        requete.id_utilisateur,
        requete.role_utilisateur,
        requete.service,
        requete.anonymisation_active,
    )

    async def generer() -> AsyncIterator[str]:
        yield f"data: {{\"id_session\": \"{session.id_session}\"}}\n\n"
        async for fragment in orchestrateur.traiter_requete(session, requete.message):
            # Échappement JSON minimal pour SSE
            fragment_json = fragment.replace('"', '\\"').replace('\n', '\\n')
            yield f"data: {{\"fragment\": \"{fragment_json}\"}}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generer(), media_type="text/event-stream")


@app.websocket("/api/v1/ws/{id_session}")
async def websocket_chat(
    websocket: WebSocket,
    id_session: str,
    orchestrateur: OrchestratorPilote = Depends(get_orchestrateur),
):
    """
    WebSocket pour le dialogue en temps réel avec l'Agent Pilote.
    Format attendu : JSON {"message": "...", "id_utilisateur": "...", "role_utilisateur": "..."}
    """
    await websocket.accept()
    logger.info(f"WebSocket connecté — Session: {id_session}")

    try:
        while True:
            data = await websocket.receive_json()
            session = obtenir_ou_creer_session(
                id_session,
                data.get("id_utilisateur", "inconnu"),
                data.get("role_utilisateur", "ROLE_CLINICIEN"),
                data.get("service", ""),
                data.get("anonymisation_active", True),
            )

            async for fragment in orchestrateur.traiter_requete(session, data["message"]):
                await websocket.send_json({"type": "fragment", "contenu": fragment})

            await websocket.send_json({
                "type": "fin",
                "id_session": session.id_session,
                "nb_iterations": session.nb_iterations,
            })

    except WebSocketDisconnect:
        logger.info(f"WebSocket déconnecté — Session: {id_session}")
    except Exception as exc:
        logger.error(f"Erreur WebSocket: {exc}")
        await websocket.close(code=1011)


@app.delete("/api/v1/sessions/{id_session}", tags=["Sessions"])
async def supprimer_session(id_session: str):
    """Supprime une session et purge les données associées (RGPD)."""
    if id_session in _sessions:
        del _sessions[id_session]
        return {"message": f"Session {id_session} supprimée."}
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session introuvable.")


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "serveur:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", "8000")),
        workers=int(os.getenv("WORKERS", "1")),
        log_level=os.getenv("LOG_LEVEL", "info").lower(),
        reload=os.getenv("ENVIRONMENT", "production") == "development",
    )
