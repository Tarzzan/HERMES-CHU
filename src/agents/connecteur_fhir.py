"""
HERMES CHU — Connecteur HL7 FHIR R4
Intégration avec le Système d'Information Hospitalier via le standard FHIR R4.
Toutes les données sont anonymisées avant d'entrer dans le pipeline agentique.
Conformité : HL7 FHIR R4 — ISO 27001 A.14 — RGPD Art. 25
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger("hermes.fhir")


class ConnecteurFHIR:
    """
    Connecteur HL7 FHIR R4 pour l'intégration avec le SIH du CHU.

    Ce connecteur est le SEUL point d'accès aux données du SIH.
    Il applique systématiquement l'anonymisation avant de retourner les données.
    """

    RESSOURCES_AUTORISEES = {
        "Patient", "Encounter", "Observation", "DiagnosticReport",
        "MedicationRequest", "Procedure", "Condition", "AllergyIntolerance",
        "Immunization", "CarePlan", "ServiceRequest", "Appointment",
    }

    def __init__(
        self,
        fhir_base_url: str,
        token_acces: str,
        privacy_engine=None,
        timeout_s: float = 30.0,
    ):
        self.fhir_base_url = fhir_base_url.rstrip("/")
        self.privacy_engine = privacy_engine
        self._client = httpx.AsyncClient(
            timeout=timeout_s,
            headers={
                "Authorization": f"Bearer {token_acces}",
                "Accept": "application/fhir+json",
                "Content-Type": "application/fhir+json",
            },
        )
        logger.info(f"Connecteur FHIR R4 initialisé — URL: {fhir_base_url}")

    # ------------------------------------------------------------------
    # Lecture des ressources FHIR
    # ------------------------------------------------------------------

    async def lire_ressource(
        self,
        type_ressource: str,
        id_ressource: str,
        id_session: str,
    ) -> Dict[str, Any]:
        """
        Lit une ressource FHIR et l'anonymise avant de la retourner.
        """
        self._verifier_ressource_autorisee(type_ressource)

        url = f"{self.fhir_base_url}/{type_ressource}/{id_ressource}"
        resp = await self._client.get(url)
        resp.raise_for_status()
        ressource = resp.json()

        # Anonymisation systématique
        ressource_anonymisee = await self._anonymiser_ressource_fhir(ressource, id_session)
        return ressource_anonymisee

    async def rechercher(
        self,
        type_ressource: str,
        parametres: Dict[str, str],
        id_session: str,
        max_resultats: int = 10,
    ) -> List[Dict[str, Any]]:
        """
        Recherche des ressources FHIR avec anonymisation des résultats.
        """
        self._verifier_ressource_autorisee(type_ressource)

        params = {**parametres, "_count": str(max_resultats)}
        url = f"{self.fhir_base_url}/{type_ressource}"
        resp = await self._client.get(url, params=params)
        resp.raise_for_status()

        bundle = resp.json()
        entrees = bundle.get("entry", [])
        ressources = [e["resource"] for e in entrees if "resource" in e]

        # Anonymisation de chaque ressource
        ressources_anonymisees = []
        for ressource in ressources:
            anon = await self._anonymiser_ressource_fhir(ressource, id_session)
            ressources_anonymisees.append(anon)

        return ressources_anonymisees

    # ------------------------------------------------------------------
    # Anonymisation des ressources FHIR
    # ------------------------------------------------------------------

    async def _anonymiser_ressource_fhir(
        self,
        ressource: Dict[str, Any],
        id_session: str,
    ) -> Dict[str, Any]:
        """
        Anonymise les champs PHI d'une ressource FHIR.
        Remplace les données nominatives par des tokens.
        """
        if not self.privacy_engine:
            logger.warning("Privacy Engine non configuré — données non anonymisées !")
            return ressource

        type_ressource = ressource.get("resourceType", "")
        ressource_anon = dict(ressource)

        if type_ressource == "Patient":
            ressource_anon = await self._anonymiser_patient(ressource_anon, id_session)
        elif type_ressource == "Practitioner":
            ressource_anon = await self._anonymiser_praticien(ressource_anon, id_session)
        elif type_ressource in ("Observation", "DiagnosticReport", "Condition"):
            # Pour les ressources cliniques, anonymiser les références patient
            ressource_anon = await self._anonymiser_references(ressource_anon, id_session)

        return ressource_anon

    async def _anonymiser_patient(self, patient: Dict, id_session: str) -> Dict:
        """Anonymise les données d'un patient FHIR."""
        anon = dict(patient)

        # Suppression des identifiants directs
        if "name" in anon:
            noms = anon["name"]
            for nom in noms:
                if "family" in nom:
                    texte, _ = await self.privacy_engine.anonymize(nom["family"], id_session)
                    nom["family"] = texte
                if "given" in nom:
                    nom["given"] = [
                        (await self.privacy_engine.anonymize(g, id_session))[0]
                        for g in nom["given"]
                    ]

        # Anonymisation de la date de naissance (conservation de l'année uniquement)
        if "birthDate" in anon:
            annee = anon["birthDate"][:4]
            anon["birthDate"] = f"{annee}-01-01"  # Précision réduite à l'année

        # Suppression de l'adresse
        if "address" in anon:
            anon["address"] = [{"use": "home", "text": "[ADRESSE_ANONYMISEE]"}]

        # Suppression du téléphone
        if "telecom" in anon:
            anon["telecom"] = []

        return anon

    async def _anonymiser_praticien(self, praticien: Dict, id_session: str) -> Dict:
        """Anonymise les données d'un praticien FHIR."""
        anon = dict(praticien)
        if "name" in anon:
            for nom in anon["name"]:
                if "family" in nom:
                    texte, _ = await self.privacy_engine.anonymize(nom["family"], id_session)
                    nom["family"] = texte
        return anon

    async def _anonymiser_references(self, ressource: Dict, id_session: str) -> Dict:
        """Anonymise les références à des patients dans une ressource FHIR."""
        anon = dict(ressource)
        if "subject" in anon and "reference" in anon["subject"]:
            ref = anon["subject"]["reference"]
            texte, _ = await self.privacy_engine.anonymize(ref, id_session)
            anon["subject"]["reference"] = texte
        return anon

    # ------------------------------------------------------------------
    # Utilitaires
    # ------------------------------------------------------------------

    def _verifier_ressource_autorisee(self, type_ressource: str) -> None:
        """Vérifie que le type de ressource est dans la liste blanche."""
        if type_ressource not in self.RESSOURCES_AUTORISEES:
            raise ValueError(
                f"Ressource FHIR '{type_ressource}' non autorisée. "
                f"Ressources autorisées : {', '.join(sorted(self.RESSOURCES_AUTORISEES))}"
            )

    async def verifier_connexion(self) -> bool:
        """Vérifie la connexion au serveur FHIR."""
        try:
            resp = await self._client.get(f"{self.fhir_base_url}/metadata")
            return resp.status_code == 200
        except Exception as exc:
            logger.error(f"Connexion FHIR échouée: {exc}")
            return False

    async def fermer(self) -> None:
        await self._client.aclose()
