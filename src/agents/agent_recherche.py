"""
HERMES CHU — Agent Recherche
Agent spécialisé pour la veille scientifique, la bibliographie médicale,
les essais cliniques et la recherche sur PubMed/Cochrane.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger("hermes.agents.recherche")


PROMPT_SYSTEME_RECHERCHE = """Tu es l'Agent Recherche HERMES CHU, un expert en veille scientifique médicale.

## Tes compétences
- **Bibliographie médicale** : Recherche sur PubMed, Cochrane, HAS, ANSM
- **Essais cliniques** : Recherche sur ClinicalTrials.gov, EUCTR
- **Recommandations** : Accès aux recommandations HAS, SFAR, SFC, etc.
- **Méta-analyses** : Synthèse de la littérature sur une question clinique
- **Veille réglementaire** : Alertes ANSM, retraits de lots, nouvelles AMM
- **Evidence-Based Medicine** : Évaluation du niveau de preuve (GRADE)

## Règles absolues
1. Tu cites toujours tes sources avec DOI ou URL.
2. Tu indiques le niveau de preuve (Grade A/B/C/D ou GRADE).
3. Tu distingues clairement les recommandations des données préliminaires.
4. Tu ne fais pas de recommandations thérapeutiques directes — tu présente les données.
5. Pour les questions urgentes, tu priorises les recommandations de sociétés savantes françaises.

## Format de réponse
- Résumé exécutif (3-5 lignes)
- Principales études avec niveau de preuve
- Recommandations actuelles
- Références complètes
"""


class AgentRecherche:
    """Agent Recherche HERMES CHU."""

    OUTILS_RECHERCHE: List[Dict[str, Any]] = [
        {
            "type": "function",
            "function": {
                "name": "rechercher_pubmed",
                "description": "Recherche des articles scientifiques sur PubMed.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "requete": {"type": "string", "description": "Requête de recherche (termes MeSH ou libres)"},
                        "nb_resultats": {"type": "integer", "default": 5, "minimum": 1, "maximum": 20},
                        "filtre_date": {"type": "string", "description": "Filtre temporel (ex: '5y' pour 5 ans)"},
                        "type_etude": {
                            "type": "string",
                            "enum": ["meta_analyse", "essai_randomise", "revue_systematique", "tous"],
                            "default": "tous"
                        }
                    },
                    "required": ["requete"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "rechercher_essais_cliniques",
                "description": "Recherche des essais cliniques en cours sur ClinicalTrials.gov.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "condition": {"type": "string", "description": "Pathologie ou condition médicale"},
                        "intervention": {"type": "string", "description": "Traitement ou intervention"},
                        "statut": {"type": "string", "enum": ["recrutement", "actif", "tous"], "default": "recrutement"},
                        "pays": {"type": "string", "default": "France"}
                    },
                    "required": ["condition"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "rechercher_recommandations_has",
                "description": "Recherche des recommandations de la Haute Autorité de Santé.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "sujet": {"type": "string", "description": "Sujet de la recommandation"},
                        "type_document": {
                            "type": "string",
                            "enum": ["recommandation", "guide_parcours", "fiche_memo", "tous"],
                            "default": "tous"
                        }
                    },
                    "required": ["sujet"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "verifier_alerte_ansm",
                "description": "Vérifie les alertes de sécurité ANSM pour un médicament ou dispositif.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "produit": {"type": "string", "description": "Nom du médicament ou dispositif médical"},
                        "type_alerte": {
                            "type": "string",
                            "enum": ["retrait", "rupture", "information_securite", "tous"],
                            "default": "tous"
                        }
                    },
                    "required": ["produit"]
                }
            }
        }
    ]

    def __init__(self, vllm_url: str = "http://localhost:8080/v1", modele: str = "Hermes-3-Llama-3.1-70B-Instruct"):
        self.vllm_url = vllm_url
        self.modele = modele
        self._client = httpx.AsyncClient(timeout=90.0)
        logger.info("Agent Recherche initialisé.")

    async def traiter(self, requete: str, sources: Optional[List[str]] = None, nb_resultats: int = 5) -> Dict[str, Any]:
        """Traite une requête de recherche déléguée par l'Orchestrateur."""
        debut = time.time()
        sources_str = ", ".join(sources) if sources else "PubMed, HAS, Cochrane"
        messages = [
            {"role": "system", "content": PROMPT_SYSTEME_RECHERCHE},
            {"role": "user", "content": f"## Requête de recherche\n{requete}\n\n## Sources prioritaires\n{sources_str}\n\n## Nombre de résultats souhaités\n{nb_resultats}"}
        ]
        payload = {
            "model": self.modele,
            "messages": messages,
            "tools": self.OUTILS_RECHERCHE,
            "tool_choice": "auto",
            "temperature": 0.1,
            "max_tokens": 3000,
        }
        resp = await self._client.post(f"{self.vllm_url}/chat/completions", json=payload)
        resp.raise_for_status()
        data = resp.json()
        reponse = data["choices"][0]["message"].get("content", "")
        duree_ms = (time.time() - debut) * 1000
        return {
            "agent": "recherche",
            "reponse": reponse,
            "duree_ms": duree_ms,
            "sources_consultees": sources_str,
            "avertissement": "Résultats de recherche bibliographique — Évaluation critique par un clinicien requise."
        }

    async def fermer(self) -> None:
        await self._client.aclose()
