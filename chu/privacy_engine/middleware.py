"""
HERMES CHU — Privacy Engine Middleware RGPD
============================================
Ce module s'insère dans le pipeline hermes-agent (NousResearch) en tant que
middleware sur les messages entrants et sortants.

Architecture :
  Message utilisateur → [Privacy Engine IN] → LLM (Hermes/Azure/OpenAI)
                      → [Privacy Engine OUT] → Réponse restituée

Le Privacy Engine est ACTIVÉ par défaut. Il peut être désactivé temporairement
via le mode "glass-break" qui exige une justification et génère une entrée
immuable dans le journal d'audit ISO 27001.

Compatibilité : s'intègre sur agent/message_sanitization.py et
agent/conversation_loop.py de hermes-agent (NousResearch).
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Patterns regex PHI — Backend "regex" (POC, sans dépendance ML)
# En production, remplacer par le backend "spacy" ou "camembert_bio"
# ---------------------------------------------------------------------------

_PHI_PATTERNS: Dict[str, re.Pattern] = {
    "NIR": re.compile(
        r"\b[12][0-9]{2}(0[1-9]|1[0-2]|[2-9][0-9]|[6-9][0-9])"
        r"(0[1-9]|[1-8][0-9]|9[0-5]|2[abAB])[0-9]{6}[0-9]{2}\b"
    ),
    "IPP": re.compile(r"\bIPP\s*:?\s*[0-9]{6,12}\b", re.IGNORECASE),
    "TELEPHONE": re.compile(r"\b0[1-9](?:[\s.\-]?[0-9]{2}){4}\b"),
    "EMAIL": re.compile(r"\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b"),
    "DATE_NAISSANCE": re.compile(
        r"\b(?:né(?:e)?\s+le\s+|naissance\s*:?\s*)"
        r"(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})\b",
        re.IGNORECASE,
    ),
    "NUMERO_SEJOUR": re.compile(r"\bséjour\s*:?\s*[0-9]{8,14}\b", re.IGNORECASE),
    "ADRESSE": re.compile(
        r"\b\d{1,4}\s+(?:rue|avenue|boulevard|allée|impasse|chemin|route|place)"
        r"\s+[A-Za-zÀ-ÿ\s\-']{3,40}\b",
        re.IGNORECASE,
    ),
}

# Noms propres médicaux communs à préserver (ne pas anonymiser)
_TERMES_MEDICAUX_EXCLUS = frozenset([
    "aspirine", "paracétamol", "ibuprofène", "amoxicilline",
    "metformine", "insuline", "cortisone", "morphine",
])


# ---------------------------------------------------------------------------
# Dataclasses
# ---------------------------------------------------------------------------

@dataclass
class EntitePHI:
    """Représente une entité PHI détectée dans un texte."""
    type_entite: str
    valeur_originale: str
    token: str
    position_debut: int
    position_fin: int


@dataclass
class ResultatAnonymisation:
    """Résultat d'une opération d'anonymisation."""
    texte_anonymise: str
    entites_detectees: List[EntitePHI]
    taux_anonymisation: float
    session_id: str
    timestamp: str


@dataclass
class EvenementAudit:
    """Événement d'audit ISO 27001 immuable (chaîné par hash SHA-256)."""
    id: str
    timestamp: str
    type_evenement: str
    utilisateur_id: str
    session_id: str
    details: Dict[str, Any]
    hash_precedent: str
    hash_courant: str = field(default="", init=False)

    def __post_init__(self):
        contenu = json.dumps({
            "id": self.id,
            "timestamp": self.timestamp,
            "type": self.type_evenement,
            "utilisateur": self.utilisateur_id,
            "session": self.session_id,
            "details": self.details,
            "hash_precedent": self.hash_precedent,
        }, sort_keys=True, ensure_ascii=False)
        self.hash_courant = hashlib.sha256(contenu.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Journal d'audit (en mémoire pour le POC, PostgreSQL en production)
# ---------------------------------------------------------------------------

class JournalAudit:
    """Journal d'audit immuable avec chaînage de hash SHA-256."""

    def __init__(self):
        self._entrees: List[EvenementAudit] = []
        self._dernier_hash = "0" * 64  # Hash genesis

    def enregistrer(
        self,
        type_evenement: str,
        utilisateur_id: str,
        session_id: str,
        details: Dict[str, Any],
    ) -> EvenementAudit:
        evenement = EvenementAudit(
            id=str(uuid.uuid4()),
            timestamp=datetime.now(timezone.utc).isoformat(),
            type_evenement=type_evenement,
            utilisateur_id=utilisateur_id,
            session_id=session_id,
            details=details,
            hash_precedent=self._dernier_hash,
        )
        self._dernier_hash = evenement.hash_courant
        self._entrees.append(evenement)
        logger.info(
            "[AUDIT] %s | utilisateur=%s | session=%s | hash=%s",
            type_evenement, utilisateur_id, session_id,
            evenement.hash_courant[:16] + "...",
        )
        return evenement

    def exporter(self) -> List[Dict[str, Any]]:
        return [
            {
                "id": e.id,
                "timestamp": e.timestamp,
                "type": e.type_evenement,
                "utilisateur": e.utilisateur_id,
                "session": e.session_id,
                "details": e.details,
                "hash": e.hash_courant,
            }
            for e in self._entrees
        ]


# Singleton global du journal
_journal_audit = JournalAudit()


# ---------------------------------------------------------------------------
# Table de correspondance token ↔ PHI (Redis en production, dict en POC)
# ---------------------------------------------------------------------------

class TableCorrespondance:
    """
    Stocke la correspondance token → valeur PHI réelle.
    En production : Redis avec TTL 1h et chiffrement AES-256.
    En POC : dictionnaire en mémoire.
    """

    def __init__(self):
        self._table: Dict[str, str] = {}

    def stocker(self, token: str, valeur_reelle: str) -> None:
        self._table[token] = valeur_reelle

    def recuperer(self, token: str) -> Optional[str]:
        return self._table.get(token)

    def supprimer_session(self, session_id: str) -> None:
        """Supprime toutes les entrées d'une session (droit à l'effacement RGPD)."""
        cles_a_supprimer = [k for k in self._table if k.startswith(f"[{session_id[:8]}")]
        for cle in cles_a_supprimer:
            del self._table[cle]


_table_correspondance = TableCorrespondance()


# ---------------------------------------------------------------------------
# Moteur d'anonymisation principal
# ---------------------------------------------------------------------------

class PrivacyEngine:
    """
    Middleware d'anonymisation RGPD pour HERMES CHU.

    Utilisation dans hermes-agent :
        engine = PrivacyEngine()

        # Avant envoi au LLM :
        texte_safe, resultat = engine.anonymiser(texte_brut, session_id, user_id)

        # Après réception du LLM :
        texte_final = engine.controle_sortie(reponse_llm, session_id)
    """

    def __init__(self, actif: bool = True):
        self.actif = actif
        self._sessions_glass_break: Dict[str, Dict[str, Any]] = {}

    # ------------------------------------------------------------------
    # API publique
    # ------------------------------------------------------------------

    def anonymiser(
        self,
        texte: str,
        session_id: str,
        utilisateur_id: str = "anonyme",
    ) -> Tuple[str, ResultatAnonymisation]:
        """
        Anonymise le texte en remplaçant les PHI par des tokens déterministes.
        Retourne (texte_anonymisé, résultat_détaillé).
        """
        if not self.actif or self._est_glass_break_actif(session_id):
            # Journaliser si glass-break
            if self._est_glass_break_actif(session_id):
                _journal_audit.enregistrer(
                    "ANONYMISATION_CONTOURNEE_GLASS_BREAK",
                    utilisateur_id, session_id,
                    {"raison": self._sessions_glass_break[session_id].get("justification")},
                )
            return texte, ResultatAnonymisation(
                texte_anonymise=texte,
                entites_detectees=[],
                taux_anonymisation=0.0,
                session_id=session_id,
                timestamp=datetime.now(timezone.utc).isoformat(),
            )

        entites = self._detecter_phi(texte)
        texte_anonymise = self._remplacer_phi(texte, entites, session_id)
        taux = len(entites) / max(len(texte.split()), 1) * 100

        if entites:
            _journal_audit.enregistrer(
                "ANONYMISATION_EFFECTUEE",
                utilisateur_id, session_id,
                {
                    "nb_entites": len(entites),
                    "types": list({e.type_entite for e in entites}),
                    "taux_anonymisation": round(taux, 2),
                },
            )

        return texte_anonymise, ResultatAnonymisation(
            texte_anonymise=texte_anonymise,
            entites_detectees=entites,
            taux_anonymisation=round(taux, 2),
            session_id=session_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
        )

    def scanner_phi(self, texte: str, session_id: str = "scan") -> ResultatAnonymisation:
        """
        Scanne un texte pour détecter les PHI SANS le modifier.
        Utilisé par les patches (patch_hermes.py) pour vérifier les sorties LLM
        et par l'API métriques. Le texte retourné est inchangé.
        """
        entites = self._detecter_phi(texte)
        taux = len(entites) / max(len(texte.split()), 1) * 100
        return ResultatAnonymisation(
            texte_anonymise=texte,
            entites_detectees=entites,
            taux_anonymisation=round(taux, 2),
            session_id=session_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
        )

    def controle_sortie(self, texte: str, session_id: str) -> str:
        """
        Garde-fou Niveau 3 : rescanne la sortie du LLM pour détecter
        tout PHI résiduel et le masquer avant restitution à l'utilisateur.
        """
        entites_residuelles = self._detecter_phi(texte)
        if entites_residuelles:
            logger.warning(
                "[GARDE-FOU-N3] %d PHI résiduels détectés en sortie LLM — masquage forcé",
                len(entites_residuelles),
            )
            texte = self._remplacer_phi(texte, entites_residuelles, session_id)
        return texte

    def activer_glass_break(
        self,
        session_id: str,
        utilisateur_id: str,
        justification: str,
        duree_minutes: int = 30,
    ) -> bool:
        """
        Active le mode glass-break pour une session.
        Exige une justification textuelle et génère une entrée d'audit immuable.
        """
        if not justification or len(justification.strip()) < 20:
            logger.error("[GLASS-BREAK] Justification insuffisante (minimum 20 caractères)")
            return False

        self._sessions_glass_break[session_id] = {
            "utilisateur_id": utilisateur_id,
            "justification": justification.strip(),
            "debut": time.time(),
            "duree_secondes": duree_minutes * 60,
        }

        _journal_audit.enregistrer(
            "GLASS_BREAK_ACTIVE",
            utilisateur_id, session_id,
            {
                "justification": justification.strip(),
                "duree_minutes": duree_minutes,
                "alerte": "ANONYMISATION_DESACTIVEE",
            },
        )

        logger.warning(
            "[GLASS-BREAK] ⚠️  Anonymisation désactivée pour session=%s | "
            "utilisateur=%s | durée=%dmin | justification='%s'",
            session_id[:8], utilisateur_id, duree_minutes, justification[:50],
        )
        return True

    def desactiver_glass_break(self, session_id: str, utilisateur_id: str) -> None:
        """Désactive le mode glass-break et journalise la fin."""
        if session_id in self._sessions_glass_break:
            duree_reelle = time.time() - self._sessions_glass_break[session_id]["debut"]
            del self._sessions_glass_break[session_id]
            _journal_audit.enregistrer(
                "GLASS_BREAK_DESACTIVE",
                utilisateur_id, session_id,
                {"duree_reelle_secondes": round(duree_reelle)},
            )

    def get_statut(self, session_id: str) -> Dict[str, Any]:
        """Retourne le statut du Privacy Engine pour une session."""
        glass_break = self._sessions_glass_break.get(session_id)
        return {
            "actif": self.actif,
            "glass_break": glass_break is not None,
            "glass_break_details": glass_break,
            "journal_entrees": len(_journal_audit._entrees),
        }

    # ------------------------------------------------------------------
    # Méthodes privées
    # ------------------------------------------------------------------

    def _detecter_phi(self, texte: str) -> List[EntitePHI]:
        """Détecte les entités PHI dans le texte via les patterns regex."""
        entites: List[EntitePHI] = []
        for type_entite, pattern in _PHI_PATTERNS.items():
            for match in pattern.finditer(texte):
                valeur = match.group(0)
                # Exclure les termes médicaux connus
                if valeur.lower() in _TERMES_MEDICAUX_EXCLUS:
                    continue
                token = self._generer_token(type_entite, valeur)
                entites.append(EntitePHI(
                    type_entite=type_entite,
                    valeur_originale=valeur,
                    token=token,
                    position_debut=match.start(),
                    position_fin=match.end(),
                ))
        # Trier par position décroissante pour remplacer sans décalage d'index
        entites.sort(key=lambda e: e.position_debut, reverse=True)
        return entites

    def _remplacer_phi(
        self, texte: str, entites: List[EntitePHI], session_id: str
    ) -> str:
        """Remplace les PHI par leurs tokens dans le texte."""
        for entite in entites:
            _table_correspondance.stocker(entite.token, entite.valeur_originale)
            texte = (
                texte[:entite.position_debut]
                + entite.token
                + texte[entite.position_fin:]
            )
        return texte

    def _generer_token(self, type_entite: str, valeur: str) -> str:
        """Génère un token déterministe pour une entité PHI."""
        hash_val = hashlib.sha256(valeur.encode()).hexdigest()[:8]
        return f"[{type_entite}_{hash_val}]"

    def _est_glass_break_actif(self, session_id: str) -> bool:
        """Vérifie si le mode glass-break est actif et non expiré pour une session."""
        info = self._sessions_glass_break.get(session_id)
        if not info:
            return False
        if time.time() - info["debut"] > info["duree_secondes"]:
            # Expiration automatique
            self.desactiver_glass_break(session_id, info["utilisateur_id"])
            return False
        return True


# ---------------------------------------------------------------------------
# Singleton global du Privacy Engine
# ---------------------------------------------------------------------------

_privacy_engine: Optional[PrivacyEngine] = None


def get_privacy_engine() -> PrivacyEngine:
    """Retourne le singleton du Privacy Engine (initialisé à la demande)."""
    global _privacy_engine
    if _privacy_engine is None:
        actif = os.environ.get("CHU_PRIVACY_ENGINE_ACTIF", "true").lower() == "true"
        _privacy_engine = PrivacyEngine(actif=actif)
        logger.info(
            "[PRIVACY ENGINE] Initialisé | actif=%s | backend=regex",
            actif,
        )
    return _privacy_engine


def get_journal_audit() -> JournalAudit:
    """Retourne le singleton du journal d'audit."""
    return _journal_audit
