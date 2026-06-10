"""
HERMES CHU — Agent Logistique
Agent spécialisé pour la gestion des ressources hospitalières :
lits, blocs opératoires, équipements, stocks, planification du personnel.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List

import httpx

logger = logging.getLogger("hermes.agents.logistique")


PROMPT_SYSTEME_LOGISTIQUE = """Tu es l'Agent Logistique HERMES CHU, un expert en gestion des ressources hospitalières.

## Tes compétences
- **Gestion des lits** : Disponibilité, taux d'occupation, prévisions d'admission
- **Blocs opératoires** : Planification des interventions, gestion des créneaux
- **Équipements** : Suivi de disponibilité, maintenance préventive, alertes
- **Stocks** : Gestion des consommables médicaux, alertes de rupture, commandes
- **Planification** : Aide à l'organisation des équipes, gardes, astreintes
- **Flux patients** : Optimisation des parcours, réduction des temps d'attente

## Règles absolues
1. Tu travailles uniquement sur des données anonymisées.
2. Toute modification de planning ou de ressource doit être validée par le responsable de service.
3. En cas de situation critique (rupture de stock médicament vital, saturation des lits), tu alertes immédiatement.
4. Tu ne prends jamais de décision autonome sur les ressources — tu proposes et recommandes.
"""


class AgentLogistique:
    """Agent Logistique HERMES CHU."""

    OUTILS_LOGISTIQUES: List[Dict[str, Any]] = [
        {
            "type": "function",
            "function": {
                "name": "consulter_disponibilite_lits",
                "description": "Consulte la disponibilité des lits par service.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "service": {"type": "string", "description": "Service hospitalier (ou 'tous')"},
                        "type_lit": {"type": "string", "enum": ["hospitalisation", "reanimation", "urgences", "chirurgie", "tous"]}
                    },
                    "required": []
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "consulter_planning_bloc",
                "description": "Consulte le planning des blocs opératoires.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "date": {"type": "string", "description": "Date au format YYYY-MM-DD"},
                        "salle": {"type": "string", "description": "Numéro de salle (ou 'toutes')"}
                    },
                    "required": ["date"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "verifier_stock",
                "description": "Vérifie le niveau de stock d'un consommable ou médicament.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "article": {"type": "string", "description": "Nom ou référence de l'article"},
                        "service": {"type": "string", "description": "Service concerné"}
                    },
                    "required": ["article"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "generer_rapport_occupation",
                "description": "Génère un rapport d'occupation et de flux pour un service.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "service": {"type": "string"},
                        "periode": {"type": "string", "enum": ["jour", "semaine", "mois"]},
                        "indicateurs": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Indicateurs à inclure (taux_occupation, DMS, rotations, etc.)"
                        }
                    },
                    "required": ["service", "periode"]
                }
            }
        }
    ]

    def __init__(self, vllm_url: str = "http://localhost:8080/v1", modele: str = "Hermes-3-Llama-3.1-70B-Instruct"):
        self.vllm_url = vllm_url
        self.modele = modele
        self._client = httpx.AsyncClient(timeout=30.0)
        logger.info("Agent Logistique initialisé.")

    async def traiter(self, tache: str, ressource: str, service: str = "") -> Dict[str, Any]:
        """Traite une tâche logistique déléguée par l'Orchestrateur."""
        debut = time.time()
        messages = [
            {"role": "system", "content": PROMPT_SYSTEME_LOGISTIQUE},
            {"role": "user", "content": f"## Tâche\n{tache}\n\n## Ressource\n{ressource}\n\n## Service\n{service}"}
        ]
        payload = {
            "model": self.modele,
            "messages": messages,
            "tools": self.OUTILS_LOGISTIQUES,
            "tool_choice": "auto",
            "temperature": 0.1,
            "max_tokens": 1500,
        }
        resp = await self._client.post(f"{self.vllm_url}/chat/completions", json=payload)
        resp.raise_for_status()
        data = resp.json()
        reponse = data["choices"][0]["message"].get("content", "")
        duree_ms = (time.time() - debut) * 1000
        return {
            "agent": "logistique",
            "reponse": reponse,
            "duree_ms": duree_ms,
            "ressource": ressource,
            "avertissement": "Proposition logistique — Validation par le responsable de service requise."
        }

    async def fermer(self) -> None:
        await self._client.aclose()
