"""
HERMES CHU — Point d'entrée de l'Orchestrateur (Agent Pilote)
==============================================================
Lance le serveur FastAPI défini dans serveur.py (API REST + SSE + WebSocket).

Utilisation :
    python main.py                       # depuis src/orchestrator/
    python src/orchestrator/main.py      # depuis la racine du dépôt

Variables d'environnement :
    PORT         Port d'écoute (défaut : 8000)
    WORKERS      Nombre de workers uvicorn (défaut : 1)
    LOG_LEVEL    Niveau de log (défaut : info)
    ENVIRONMENT  "development" active le rechargement à chaud
"""

from __future__ import annotations

import logging
import os
import sys
from pathlib import Path

# Garantit l'import de serveur.py quel que soit le répertoire de lancement
sys.path.insert(0, str(Path(__file__).parent))

# Format de log horodaté avec fichier:ligne (exigence traçabilité ISO 27001)
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
    format="%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s",
)
logger = logging.getLogger("hermes-pilote")


def main() -> None:
    import uvicorn

    port = int(os.getenv("PORT", "8000"))
    logger.info("Démarrage du service Orchestrateur HERMES CHU sur le port %d...", port)
    uvicorn.run(
        "serveur:app",
        host="0.0.0.0",
        port=port,
        workers=int(os.getenv("WORKERS", "1")),
        log_level=os.getenv("LOG_LEVEL", "info").lower(),
        reload=os.getenv("ENVIRONMENT", "production") == "development",
    )


if __name__ == "__main__":
    main()
