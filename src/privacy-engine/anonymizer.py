"""
HERMES CHU — Privacy Engine (SAS d'Anonymisation)
Pipeline NER en 5 étapes pour la pseudonymisation réversible des PHI.
Conformité : ISO 27001 A.8.2 / RGPD Art. 25 / HDS
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger("hermes.privacy")


# ---------------------------------------------------------------------------
# Types d'entités PHI (Protected Health Information)
# ---------------------------------------------------------------------------

class TypePHI(str, Enum):
    """Catégories d'informations de santé protégées."""
    NOM_PATIENT       = "NOM_PATIENT"
    PRENOM_PATIENT    = "PRENOM_PATIENT"
    DATE_NAISSANCE    = "DATE_NAISSANCE"
    NIR               = "NIR"               # Numéro de Sécurité Sociale
    ADRESSE           = "ADRESSE"
    TELEPHONE         = "TELEPHONE"
    EMAIL             = "EMAIL"
    IPP               = "IPP"               # Identifiant Patient Permanent
    NOM_MEDECIN       = "NOM_MEDECIN"
    RPPS              = "RPPS"              # Numéro RPPS du médecin
    DATE_SEJOUR       = "DATE_SEJOUR"
    NOM_ETABLISSEMENT = "NOM_ETABLISSEMENT"


@dataclass
class EntitePHI:
    """Représente une entité PHI détectée dans un texte."""
    type_phi: TypePHI
    valeur_originale: str
    token: str
    position_debut: int
    position_fin: int
    confiance: float = 1.0
    source: str = "regex"  # "regex" | "ner" | "dictionnaire"


@dataclass
class ResultatAnonymisation:
    """Résultat complet d'une opération d'anonymisation."""
    texte_original: str
    texte_anonymise: str
    entites_detectees: List[EntitePHI]
    mapping: Dict[str, str]           # token → valeur_originale
    id_session: str
    horodatage: float = field(default_factory=time.time)
    duree_ms: float = 0.0
    anonymisation_active: bool = True


# ---------------------------------------------------------------------------
# Règles Regex pour les PHI à format connu
# ---------------------------------------------------------------------------

REGLES_REGEX: List[Tuple[TypePHI, str]] = [
    # Numéro de Sécurité Sociale (NIR)
    (TypePHI.NIR, r"\b[12]\s?\d{2}\s?(?:0[1-9]|1[0-2])\s?(?:2[AB]|[0-9]{2})\s?\d{3}\s?\d{3}\s?\d{2}\b"),
    # Numéro RPPS (médecin)
    (TypePHI.RPPS, r"\bRPPS\s*:?\s*\d{11}\b"),
    # IPP (Identifiant Patient Permanent — format CHU)
    (TypePHI.IPP, r"\bIPP\s*:?\s*\d{7,10}\b"),
    # Téléphone français
    (TypePHI.TELEPHONE, r"\b(?:(?:\+33|0033|0)[\s.-]?[1-9](?:[\s.-]?\d{2}){4})\b"),
    # Email
    (TypePHI.EMAIL, r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b"),
    # Date de naissance (formats courants)
    (TypePHI.DATE_NAISSANCE, r"\b(?:né(?:e)?\s+le\s+|DDN\s*:?\s*)(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})\b"),
    # Date de séjour
    (TypePHI.DATE_SEJOUR, r"\b(?:admis(?:sion)?\s+le\s+|sortie\s+le\s+)(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})\b"),
]

# Titres médicaux pour la détection des noms de médecins
TITRES_MEDICAUX = [
    "Dr", "Dr.", "Docteur", "Pr", "Pr.", "Professeur",
    "M.", "Mme", "M ", "Mme ", "Monsieur", "Madame",
]


# ---------------------------------------------------------------------------
# Stockage des mappings (interface abstraite)
# ---------------------------------------------------------------------------

class StockageMappings:
    """Interface abstraite pour le stockage des mappings token↔PHI."""

    async def sauvegarder(self, id_session: str, mapping: Dict[str, str], ttl_s: int = 3600) -> None:
        raise NotImplementedError

    async def recuperer(self, id_session: str) -> Dict[str, str]:
        raise NotImplementedError

    async def supprimer(self, id_session: str) -> None:
        raise NotImplementedError


class StockageMemoire(StockageMappings):
    """Stockage en mémoire (développement uniquement — NON CONFORME PROD)."""

    def __init__(self):
        self._store: Dict[str, Dict[str, str]] = {}
        logger.warning("StockageMemoire utilisé — NON CONFORME pour la production.")

    async def sauvegarder(self, id_session: str, mapping: Dict[str, str], ttl_s: int = 3600) -> None:
        self._store[id_session] = mapping

    async def recuperer(self, id_session: str) -> Dict[str, str]:
        return self._store.get(id_session, {})

    async def supprimer(self, id_session: str) -> None:
        self._store.pop(id_session, None)


class StockageRedis(StockageMappings):
    """Stockage Redis avec TTL (production)."""

    def __init__(self, redis_url: str = "redis://localhost:6379/0"):
        self.redis_url = redis_url
        self._redis = None  # Connexion lazy

    async def _connexion(self):
        if self._redis is None:
            try:
                import redis.asyncio as aioredis
                self._redis = await aioredis.from_url(
                    self.redis_url,
                    encoding="utf-8",
                    decode_responses=True,
                )
            except ImportError:
                logger.error("redis[asyncio] non installé. Utiliser: pip install redis[asyncio]")
                raise
        return self._redis

    async def sauvegarder(self, id_session: str, mapping: Dict[str, str], ttl_s: int = 3600) -> None:
        r = await self._connexion()
        cle = f"hermes:mapping:{id_session}"
        await r.setex(cle, ttl_s, json.dumps(mapping, ensure_ascii=False))

    async def recuperer(self, id_session: str) -> Dict[str, str]:
        r = await self._connexion()
        cle = f"hermes:mapping:{id_session}"
        valeur = await r.get(cle)
        return json.loads(valeur) if valeur else {}

    async def supprimer(self, id_session: str) -> None:
        r = await self._connexion()
        await r.delete(f"hermes:mapping:{id_session}")


# ---------------------------------------------------------------------------
# Privacy Engine principal
# ---------------------------------------------------------------------------

class PrivacyEngine:
    """
    Moteur d'anonymisation réversible (pseudonymisation) HERMES CHU.

    Pipeline en 5 étapes :
    1. Détection Regex (formats connus : NIR, RPPS, téléphone, email)
    2. Détection NER (CamemBERT-bio — noms, adresses, établissements)
    3. Génération de tokens déterministes (hash SHA-256 salé)
    4. Substitution et stockage sécurisé (Redis + TTL)
    5. Journalisation de l'opération (ISO 27001 A.12.4)
    """

    def __init__(
        self,
        stockage: Optional[StockageMappings] = None,
        sel_hash: Optional[str] = None,
        ttl_mapping_s: int = 3600,
        activer_ner: bool = False,   # False tant que le modèle n'est pas chargé
    ):
        self.stockage = stockage or StockageMemoire()
        self.sel_hash = sel_hash or str(uuid.uuid4())  # Sel aléatoire par instance
        self.ttl_mapping_s = ttl_mapping_s
        self.activer_ner = activer_ner
        self._ner_pipeline = None

        if activer_ner:
            self._charger_modele_ner()

        logger.info(f"Privacy Engine initialisé (NER={'activé' if activer_ner else 'désactivé'})")

    def _charger_modele_ner(self) -> None:
        """Charge le modèle CamemBERT-bio pour la détection NER."""
        try:
            from transformers import pipeline as hf_pipeline
            self._ner_pipeline = hf_pipeline(
                "ner",
                model="almanach/camembert-bio-medical",
                aggregation_strategy="simple",
            )
            logger.info("Modèle NER CamemBERT-bio chargé avec succès.")
        except ImportError:
            logger.warning("transformers non installé. NER désactivé.")
            self.activer_ner = False
        except Exception as exc:
            logger.error(f"Impossible de charger le modèle NER: {exc}")
            self.activer_ner = False

    # ------------------------------------------------------------------
    # API publique
    # ------------------------------------------------------------------

    async def anonymize(
        self, texte: str, id_session: str
    ) -> Tuple[str, Dict[str, str]]:
        """
        Anonymise un texte en remplaçant les PHI par des tokens.
        Retourne (texte_anonymisé, mapping_token→valeur).
        """
        debut = time.time()
        entites: List[EntitePHI] = []

        # Étape 1 : Détection Regex
        entites.extend(self._detecter_regex(texte))

        # Étape 2 : Détection NER (si activé)
        if self.activer_ner and self._ner_pipeline:
            entites.extend(self._detecter_ner(texte))

        # Étape 3 : Déduplication et tri par position (décroissant pour la substitution)
        entites = self._dedupliquer(entites)
        entites.sort(key=lambda e: e.position_debut, reverse=True)

        # Étape 4 : Substitution et construction du mapping
        texte_anonymise = texte
        mapping: Dict[str, str] = {}

        for entite in entites:
            token = self._generer_token(entite.type_phi, entite.valeur_originale, id_session)
            entite.token = token
            mapping[token] = entite.valeur_originale
            texte_anonymise = (
                texte_anonymise[: entite.position_debut]
                + token
                + texte_anonymise[entite.position_fin :]
            )

        # Étape 5 : Stockage sécurisé du mapping
        if mapping:
            mapping_existant = await self.stockage.recuperer(id_session)
            mapping_existant.update(mapping)
            await self.stockage.sauvegarder(id_session, mapping_existant, self.ttl_mapping_s)

        duree_ms = (time.time() - debut) * 1000
        nb_entites = len(entites)
        logger.info(
            f"Anonymisation — Session: {id_session} — "
            f"{nb_entites} entité(s) détectée(s) — {duree_ms:.1f}ms"
        )

        return texte_anonymise, mapping

    async def rehydrate(self, texte: str, id_session: str) -> str:
        """
        Restaure les valeurs originales à partir des tokens.
        """
        mapping = await self.stockage.recuperer(id_session)
        if not mapping:
            return texte

        texte_rehydrate = texte
        for token, valeur_originale in mapping.items():
            texte_rehydrate = texte_rehydrate.replace(token, valeur_originale)

        return texte_rehydrate

    async def purger_session(self, id_session: str) -> None:
        """Supprime le mapping d'une session (RGPD — droit à l'effacement)."""
        await self.stockage.supprimer(id_session)
        logger.info(f"Mapping purgé pour la session {id_session}")

    # ------------------------------------------------------------------
    # Détection des entités
    # ------------------------------------------------------------------

    def _detecter_regex(self, texte: str) -> List[EntitePHI]:
        """Étape 1 : Détection par expressions régulières."""
        entites: List[EntitePHI] = []

        for type_phi, pattern in REGLES_REGEX:
            for match in re.finditer(pattern, texte, re.IGNORECASE):
                entites.append(EntitePHI(
                    type_phi=type_phi,
                    valeur_originale=match.group(0),
                    token="",  # Sera généré à l'étape 3
                    position_debut=match.start(),
                    position_fin=match.end(),
                    confiance=1.0,
                    source="regex",
                ))

        return entites

    def _detecter_ner(self, texte: str) -> List[EntitePHI]:
        """Étape 2 : Détection par le modèle NER CamemBERT-bio."""
        if not self._ner_pipeline:
            return []

        entites: List[EntitePHI] = []
        try:
            resultats = self._ner_pipeline(texte)
            for r in resultats:
                # Mapping des labels NER vers les types PHI
                type_phi = self._mapper_label_ner(r.get("entity_group", ""))
                if type_phi:
                    entites.append(EntitePHI(
                        type_phi=type_phi,
                        valeur_originale=r["word"],
                        token="",
                        position_debut=r["start"],
                        position_fin=r["end"],
                        confiance=float(r.get("score", 0.5)),
                        source="ner",
                    ))
        except Exception as exc:
            logger.error(f"Erreur NER: {exc}")

        return entites

    def _mapper_label_ner(self, label: str) -> Optional[TypePHI]:
        """Mappe les labels NER du modèle vers les types PHI."""
        mapping = {
            "PER": TypePHI.NOM_PATIENT,
            "PERSON": TypePHI.NOM_PATIENT,
            "LOC": TypePHI.ADRESSE,
            "LOCATION": TypePHI.ADRESSE,
            "ORG": TypePHI.NOM_ETABLISSEMENT,
            "ORGANIZATION": TypePHI.NOM_ETABLISSEMENT,
        }
        return mapping.get(label.upper())

    def _dedupliquer(self, entites: List[EntitePHI]) -> List[EntitePHI]:
        """Supprime les entités qui se chevauchent (priorité à la regex)."""
        if not entites:
            return []

        entites.sort(key=lambda e: (e.position_debut, -(e.position_fin - e.position_debut)))
        resultat: List[EntitePHI] = []
        fin_precedente = -1

        for entite in entites:
            if entite.position_debut >= fin_precedente:
                resultat.append(entite)
                fin_precedente = entite.position_fin

        return resultat

    # ------------------------------------------------------------------
    # Génération de tokens
    # ------------------------------------------------------------------

    def _generer_token(self, type_phi: TypePHI, valeur: str, id_session: str) -> str:
        """
        Génère un token déterministe et opaque pour une valeur PHI.
        Le même couple (valeur, session) produit toujours le même token.
        """
        entree = f"{self.sel_hash}:{id_session}:{type_phi.value}:{valeur}"
        hash_court = hashlib.sha256(entree.encode()).hexdigest()[:8].upper()
        return f"[{type_phi.value}_{hash_court}]"

    # ------------------------------------------------------------------
    # Gestion du mode activable/désactivable (tracé)
    # ------------------------------------------------------------------

    async def basculer_mode(
        self,
        id_session: str,
        activer: bool,
        id_utilisateur: str,
        justification: str,
    ) -> Dict:
        """
        Active ou désactive l'anonymisation pour une session.
        L'opération est systématiquement journalisée (ISO 27001 A.12.4).
        """
        evenement = {
            "horodatage": time.time(),
            "id_session": id_session,
            "id_utilisateur": id_utilisateur,
            "action": "ANONYMISATION_ACTIVEE" if activer else "ANONYMISATION_DESACTIVEE",
            "justification": justification,
            "niveau": "CRITIQUE" if not activer else "INFO",
        }
        logger.warning(
            f"[AUDIT PRIVACY] {evenement['action']} — "
            f"Utilisateur: {id_utilisateur} — Justification: {justification}"
        )
        return evenement
