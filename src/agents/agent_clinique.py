"""
HERMES CHU — Agent Clinique
Agent spécialisé pour les tâches médicales : synthèses, codage CIM-10/CCAM,
analyse de résultats biologiques, aide à la décision clinique.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger("hermes.agents.clinique")


PROMPT_SYSTEME_CLINIQUE = """Tu es l'Agent Clinique HERMES CHU, un assistant médical expert.

## Tes compétences
- **Synthèses médicales** : Résumés de dossiers, lettres de sortie, comptes-rendus
- **Codage CIM-10** : Classification internationale des maladies (10e révision)
- **Codage CCAM** : Classification commune des actes médicaux
- **Analyse biologique** : Interprétation des résultats de laboratoire
- **Aide à la décision** : Suggestions diagnostiques et thérapeutiques (aide, jamais prescription)
- **Interactions médicamenteuses** : Vérification des associations (base Thériaque)

## Règles absolues
1. Tu n'es qu'une aide à la décision. Le médecin reste seul responsable.
2. Tu travailles uniquement sur des données anonymisées (tokens [PATIENT_X]).
3. Pour toute suggestion thérapeutique, tu indiques explicitement : "Aide à la décision — validation médicale obligatoire".
4. Tu cites toujours tes sources (HAS, VIDAL, Cochrane, etc.).
5. En cas de doute, tu recommandes la consultation d'un spécialiste.

## Format de réponse
- Utilise des sections claires (## Synthèse, ## Codage, ## Recommandations)
- Indique le niveau de confiance (Élevé / Moyen / Faible)
- Cite les références utilisées
"""


class AgentClinique:
    """
    Agent Clinique HERMES CHU.
    Spécialisé dans les tâches médicales avec accès aux outils cliniques.
    """

    OUTILS_CLINIQUES: List[Dict[str, Any]] = [
        {
            "type": "function",
            "function": {
                "name": "rechercher_cim10",
                "description": "Recherche un code CIM-10 pour un diagnostic.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "terme": {"type": "string", "description": "Terme diagnostique à coder"},
                        "contexte": {"type": "string", "description": "Contexte clinique"}
                    },
                    "required": ["terme"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "rechercher_ccam",
                "description": "Recherche un code CCAM pour un acte médical.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "acte": {"type": "string", "description": "Description de l'acte médical"},
                        "specialite": {"type": "string", "description": "Spécialité médicale"}
                    },
                    "required": ["acte"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "analyser_biologie",
                "description": "Analyse et interprète des résultats biologiques.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "resultats": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "parametre": {"type": "string"},
                                    "valeur": {"type": "number"},
                                    "unite": {"type": "string"},
                                    "norme_min": {"type": "number"},
                                    "norme_max": {"type": "number"}
                                }
                            },
                            "description": "Liste des résultats biologiques"
                        },
                        "contexte_clinique": {"type": "string"}
                    },
                    "required": ["resultats"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "generer_synthese_medicale",
                "description": "Génère une synthèse médicale structurée à partir des éléments du dossier.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "type_document": {
                            "type": "string",
                            "enum": ["lettre_sortie", "compte_rendu_hospitalisation", "synthese_medicale", "resume_urgences"]
                        },
                        "elements_dossier": {"type": "string", "description": "Éléments anonymisés du dossier"},
                        "destinataire": {"type": "string", "description": "Type de destinataire (médecin_traitant, spécialiste, patient)"}
                    },
                    "required": ["type_document", "elements_dossier"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "verifier_interactions_medicamenteuses",
                "description": "Vérifie les interactions entre médicaments (base Thériaque).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "medicaments": {
                            "type": "array",
                            "items": {"type": "string"},
                            "description": "Liste des DCI (Dénominations Communes Internationales)"
                        }
                    },
                    "required": ["medicaments"]
                }
            }
        }
    ]

    def __init__(self, vllm_url: str = "http://localhost:8080/v1", modele: str = "Hermes-3-Llama-3.1-70B-Instruct"):
        self.vllm_url = vllm_url
        self.modele = modele
        self._client = httpx.AsyncClient(timeout=60.0)
        logger.info("Agent Clinique initialisé.")

    async def traiter(self, tache: str, contexte: str, urgence: str = "routine") -> Dict[str, Any]:
        """
        Traite une tâche clinique déléguée par l'Orchestrateur.
        """
        debut = time.time()
        logger.info(f"Tâche clinique reçue — Urgence: {urgence} — Tâche: {tache[:100]}")

        messages = [
            {"role": "system", "content": PROMPT_SYSTEME_CLINIQUE},
            {"role": "user", "content": f"## Tâche\n{tache}\n\n## Contexte\n{contexte}"}
        ]

        reponse = await self._appeler_llm(messages)
        duree_ms = (time.time() - debut) * 1000

        return {
            "agent": "clinique",
            "reponse": reponse,
            "duree_ms": duree_ms,
            "urgence": urgence,
            "avertissement": "Aide à la décision — Validation médicale obligatoire avant tout acte."
        }

    async def _appeler_llm(self, messages: List[Dict]) -> str:
        """Appelle le LLM pour le traitement clinique."""
        payload = {
            "model": self.modele,
            "messages": messages,
            "tools": self.OUTILS_CLINIQUES,
            "tool_choice": "auto",
            "temperature": 0.05,   # Très faible pour les tâches médicales
            "max_tokens": 3000,
        }
        resp = await self._client.post(
            f"{self.vllm_url}/chat/completions",
            json=payload,
        )
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"].get("content", "")

    async def fermer(self) -> None:
        await self._client.aclose()
