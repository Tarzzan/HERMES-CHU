"""
HERMES CHU — Agent Administratif
Agent spécialisé pour la gestion documentaire, les courriers médicaux,
la planification et les démarches administratives hospitalières.
"""

from __future__ import annotations

import logging
import time
from typing import Any, Dict, List

import httpx

logger = logging.getLogger("hermes.agents.administratif")


PROMPT_SYSTEME_ADMINISTRATIF = """Tu es l'Agent Administratif HERMES CHU, un assistant expert en gestion hospitalière.

## Tes compétences
- **Rédaction de documents** : Courriers médicaux, certificats, ordonnances (modèles), convocations
- **Gestion documentaire** : Classement, archivage, recherche dans le GED
- **Planification** : Aide à la gestion des rendez-vous, des consultations, des hospitalisations
- **Démarches administratives** : ALD, MDPH, assurance maladie, mutuelles
- **Facturation** : Aide au codage pour la facturation (T2A, GHS)
- **Conformité réglementaire** : RGPD, droit des patients, consentements

## Règles absolues
1. Tu travailles uniquement sur des données anonymisées.
2. Les documents produits sont des modèles/brouillons — validation humaine obligatoire.
3. Tu ne signes jamais de document à la place d'un professionnel de santé.
4. Pour les démarches légales, tu recommandes une vérification juridique.

## Format de réponse
- Documents structurés avec en-têtes appropriés
- Indication claire "BROUILLON — À VALIDER" sur tous les documents
- Références réglementaires citées si applicable
"""


class AgentAdministratif:
    """Agent Administratif HERMES CHU."""

    OUTILS_ADMINISTRATIFS: List[Dict[str, Any]] = [
        {
            "type": "function",
            "function": {
                "name": "generer_courrier",
                "description": "Génère un courrier médical structuré.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "type_courrier": {
                            "type": "string",
                            "enum": ["courrier_confrere", "courrier_medecin_traitant", "certificat_medical",
                                     "convocation", "compte_rendu_consultation", "lettre_information_patient"]
                        },
                        "contenu": {"type": "string", "description": "Éléments à inclure (anonymisés)"},
                        "ton": {"type": "string", "enum": ["formel", "informatif", "urgent"], "default": "formel"}
                    },
                    "required": ["type_courrier", "contenu"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "rechercher_formulaire",
                "description": "Recherche un formulaire administratif (CERFA, formulaire CPAM, etc.).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "type_demarche": {"type": "string", "description": "Type de démarche administrative"},
                        "organisme": {"type": "string", "description": "Organisme destinataire (CPAM, MDPH, etc.)"}
                    },
                    "required": ["type_demarche"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "verifier_droits_patient",
                "description": "Vérifie les droits d'un patient (ALD, CMU, AME, etc.) dans le système.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "id_patient_token": {"type": "string", "description": "Token anonymisé du patient [PATIENT_X]"},
                        "type_droit": {"type": "string", "enum": ["ald", "cmu", "ame", "mutuelle", "tous"]}
                    },
                    "required": ["id_patient_token"]
                }
            }
        }
    ]

    def __init__(self, vllm_url: str = "http://localhost:8080/v1", modele: str = "Hermes-3-Llama-3.1-70B-Instruct"):
        self.vllm_url = vllm_url
        self.modele = modele
        self._client = httpx.AsyncClient(timeout=30.0)
        logger.info("Agent Administratif initialisé.")

    async def traiter(self, tache: str, type_document: str, contexte: str = "") -> Dict[str, Any]:
        """Traite une tâche administrative déléguée par l'Orchestrateur."""
        debut = time.time()
        logger.info(f"Tâche administrative — Type: {type_document} — Tâche: {tache[:100]}")

        messages = [
            {"role": "system", "content": PROMPT_SYSTEME_ADMINISTRATIF},
            {"role": "user", "content": f"## Tâche\n{tache}\n\n## Type de document\n{type_document}\n\n## Contexte\n{contexte}"}
        ]

        payload = {
            "model": self.modele,
            "messages": messages,
            "tools": self.OUTILS_ADMINISTRATIFS,
            "tool_choice": "auto",
            "temperature": 0.2,
            "max_tokens": 2000,
        }

        resp = await self._client.post(f"{self.vllm_url}/chat/completions", json=payload)
        resp.raise_for_status()
        data = resp.json()
        reponse = data["choices"][0]["message"].get("content", "")
        duree_ms = (time.time() - debut) * 1000

        return {
            "agent": "administratif",
            "reponse": reponse,
            "duree_ms": duree_ms,
            "type_document": type_document,
            "avertissement": "BROUILLON — Validation et signature par un professionnel de santé habilité obligatoires."
        }

    async def fermer(self) -> None:
        await self._client.aclose()
