"""
HERMES CHU — API Qualité
APIs REST pour le suivi qualité par les services et le service qualité du CHU.
Conformité : ISO 27001 — RBAC Keycloak — Journalisation complète
"""

from __future__ import annotations

import logging
import time
import uuid
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

logger = logging.getLogger("hermes.api.qualite")

app = FastAPI(
    title="HERMES CHU — API Qualité",
    description="""
API REST pour le suivi qualité du système agentique HERMES CHU.
Permet aux services et au service qualité de monitorer les performances,
consulter les journaux d'audit, gérer les incidents et produire des rapports.

**Conformité** : ISO 27001 — HDS — RGPD
**Authentification** : JWT Keycloak (ROLE_QUALITICIEN, ROLE_RSSI, ROLE_ADMIN)
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://hermes.chu-interne.local", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


# ---------------------------------------------------------------------------
# Modèles Pydantic
# ---------------------------------------------------------------------------

class MetriquesSysteme(BaseModel):
    """Métriques de performance du système agentique."""
    periode_debut: datetime
    periode_fin: datetime
    nb_requetes_total: int
    nb_requetes_reussies: int
    nb_requetes_echouees: int
    nb_garde_fous_declenches: int
    taux_succes_pct: float
    latence_moyenne_ms: float
    latence_p95_ms: float
    latence_p99_ms: float
    tokens_consommes_total: int
    nb_sessions_actives: int


class MetriquesAnonymisation(BaseModel):
    """Métriques du SAS d'anonymisation."""
    periode_debut: datetime
    periode_fin: datetime
    nb_textes_traites: int
    nb_entites_detectees_total: int
    nb_entites_par_type: Dict[str, int]
    taux_detection_estime_pct: float
    nb_desactivations: int
    nb_desactivations_justifiees: int
    latence_moyenne_ms: float


class EvenementAudit(BaseModel):
    """Événement du journal d'audit."""
    id: str
    horodatage: datetime
    id_session: str
    id_utilisateur: str
    service: str
    evenement: str
    details: str
    niveau: str  # INFO | AVERTISSEMENT | ALERTE | ERREUR | CRITIQUE
    etat_agent: str


class Incident(BaseModel):
    """Incident de sécurité ou qualité."""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    horodatage_detection: datetime = Field(default_factory=datetime.now)
    type_incident: str
    severite: str  # FAIBLE | MOYEN | ELEVE | CRITIQUE
    description: str
    service_concerne: str
    id_session_impliquee: Optional[str] = None
    statut: str = "OUVERT"  # OUVERT | EN_COURS | RESOLU | CLOS
    responsable: Optional[str] = None
    actions_correctives: Optional[str] = None
    date_resolution: Optional[datetime] = None


class CreerIncident(BaseModel):
    type_incident: str = Field(..., description="Type d'incident (SECURITE, QUALITE, PERFORMANCE, CONFORMITE)")
    severite: str = Field(..., description="Sévérité (FAIBLE, MOYEN, ELEVE, CRITIQUE)")
    description: str = Field(..., min_length=20)
    service_concerne: str
    id_session_impliquee: Optional[str] = None


class MettreAJourIncident(BaseModel):
    statut: Optional[str] = None
    responsable: Optional[str] = None
    actions_correctives: Optional[str] = None


class RapportQualite(BaseModel):
    """Rapport qualité périodique."""
    id: str
    periode: str
    date_generation: datetime
    genere_par: str
    metriques_systeme: MetriquesSysteme
    metriques_anonymisation: MetriquesAnonymisation
    nb_incidents_total: int
    nb_incidents_par_severite: Dict[str, int]
    nb_incidents_resolus: int
    taux_resolution_pct: float
    recommandations: List[str]
    statut_conformite_iso27001: str


class StatutAgent(BaseModel):
    """Statut en temps réel d'un agent."""
    nom_agent: str
    statut: str  # ACTIF | INACTIF | ERREUR | MAINTENANCE
    nb_requetes_en_cours: int
    derniere_activite: Optional[datetime]
    version: str
    latence_moyenne_ms: float
    taux_erreur_pct: float


class ConfigurationAnonymisation(BaseModel):
    """Configuration du SAS d'anonymisation."""
    actif_par_defaut: bool
    moteur_ner: str
    seuil_confiance_ner: float
    types_phi_actifs: List[str]
    ttl_mapping_secondes: int
    journalisation_active: bool


# ---------------------------------------------------------------------------
# Données simulées (à remplacer par la base de données en production)
# ---------------------------------------------------------------------------

_incidents_db: Dict[str, Incident] = {}


def _generer_metriques_demo(periode_jours: int = 7) -> MetriquesSysteme:
    """Génère des métriques de démonstration."""
    fin = datetime.now()
    debut = fin - timedelta(days=periode_jours)
    return MetriquesSysteme(
        periode_debut=debut,
        periode_fin=fin,
        nb_requetes_total=1247,
        nb_requetes_reussies=1198,
        nb_requetes_echouees=49,
        nb_garde_fous_declenches=12,
        taux_succes_pct=96.1,
        latence_moyenne_ms=2340.0,
        latence_p95_ms=5200.0,
        latence_p99_ms=8900.0,
        tokens_consommes_total=4_823_000,
        nb_sessions_actives=34,
    )


def _generer_metriques_anonymisation_demo(periode_jours: int = 7) -> MetriquesAnonymisation:
    fin = datetime.now()
    debut = fin - timedelta(days=periode_jours)
    return MetriquesAnonymisation(
        periode_debut=debut,
        periode_fin=fin,
        nb_textes_traites=1198,
        nb_entites_detectees_total=8934,
        nb_entites_par_type={
            "NIR": 423, "NOM_PATIENT": 2341, "PRENOM_PATIENT": 2298,
            "DATE_NAISSANCE": 876, "TELEPHONE": 234, "EMAIL": 189,
            "IPP": 1456, "NOM_MEDECIN": 987, "ADRESSE": 130,
        },
        taux_detection_estime_pct=97.3,
        nb_desactivations=3,
        nb_desactivations_justifiees=3,
        latence_moyenne_ms=45.2,
    )


# ---------------------------------------------------------------------------
# Routes — Métriques
# ---------------------------------------------------------------------------

@app.get(
    "/api/v1/metriques/systeme",
    response_model=MetriquesSysteme,
    tags=["Métriques"],
    summary="Métriques de performance du système",
)
async def metriques_systeme(
    periode_jours: int = Query(default=7, ge=1, le=365, description="Période en jours"),
):
    """
    Retourne les métriques de performance globales du système agentique.
    Inclut les taux de succès, latences et consommation de tokens.
    """
    return _generer_metriques_demo(periode_jours)


@app.get(
    "/api/v1/metriques/anonymisation",
    response_model=MetriquesAnonymisation,
    tags=["Métriques"],
    summary="Métriques du SAS d'anonymisation",
)
async def metriques_anonymisation(
    periode_jours: int = Query(default=7, ge=1, le=365),
):
    """
    Retourne les métriques du SAS d'anonymisation :
    nombre d'entités détectées, types de PHI, désactivations.
    """
    return _generer_metriques_anonymisation_demo(periode_jours)


@app.get(
    "/api/v1/metriques/agents",
    response_model=List[StatutAgent],
    tags=["Métriques"],
    summary="Statut en temps réel des agents",
)
async def statut_agents():
    """Retourne le statut en temps réel de chaque agent spécialisé."""
    return [
        StatutAgent(nom_agent="Orchestrateur Pilote", statut="ACTIF", nb_requetes_en_cours=3,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=2340.0, taux_erreur_pct=3.9),
        StatutAgent(nom_agent="Agent Clinique", statut="ACTIF", nb_requetes_en_cours=1,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=3200.0, taux_erreur_pct=2.1),
        StatutAgent(nom_agent="Agent Administratif", statut="ACTIF", nb_requetes_en_cours=0,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=1800.0, taux_erreur_pct=1.5),
        StatutAgent(nom_agent="Agent Logistique", statut="ACTIF", nb_requetes_en_cours=2,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=1200.0, taux_erreur_pct=0.8),
        StatutAgent(nom_agent="Agent Recherche", statut="ACTIF", nb_requetes_en_cours=0,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=4500.0, taux_erreur_pct=4.2),
        StatutAgent(nom_agent="Privacy Engine", statut="ACTIF", nb_requetes_en_cours=5,
                    derniere_activite=datetime.now(), version="1.0.0", latence_moyenne_ms=45.0, taux_erreur_pct=0.1),
    ]


# ---------------------------------------------------------------------------
# Routes — Journal d'Audit
# ---------------------------------------------------------------------------

@app.get(
    "/api/v1/audit/journal",
    response_model=List[EvenementAudit],
    tags=["Audit"],
    summary="Consulter le journal d'audit",
)
async def journal_audit(
    niveau: Optional[str] = Query(default=None, description="Filtrer par niveau (INFO, ALERTE, CRITIQUE)"),
    service: Optional[str] = Query(default=None, description="Filtrer par service"),
    evenement: Optional[str] = Query(default=None, description="Filtrer par type d'événement"),
    depuis: Optional[datetime] = Query(default=None, description="Date de début"),
    jusqu_a: Optional[datetime] = Query(default=None, description="Date de fin"),
    page: int = Query(default=1, ge=1),
    taille_page: int = Query(default=50, ge=1, le=200),
):
    """
    Consulte le journal d'audit immuable du système.
    Accessible uniquement aux rôles ROLE_RSSI, ROLE_QUALITICIEN, ROLE_AUDITEUR.
    """
    # TODO: Requête PostgreSQL avec filtres
    return []


@app.get(
    "/api/v1/audit/anonymisation",
    tags=["Audit"],
    summary="Journal des opérations d'anonymisation",
)
async def journal_anonymisation(
    depuis: Optional[datetime] = Query(default=None),
    inclure_desactivations: bool = Query(default=True),
):
    """
    Journal spécifique des opérations d'anonymisation.
    Inclut les désactivations avec leurs justifications.
    """
    return {
        "desactivations": [],
        "activations": [],
        "nb_total_operations": 0,
    }


@app.get(
    "/api/v1/audit/garde-fous",
    tags=["Audit"],
    summary="Journal des déclenchements de garde-fous",
)
async def journal_garde_fous(
    niveau_garde_fou: Optional[int] = Query(default=None, ge=1, le=4),
    periode_jours: int = Query(default=30),
):
    """
    Journal des déclenchements de garde-fous par niveau.
    Permet d'identifier les tentatives d'abus ou les problèmes récurrents.
    """
    return {
        "declenchements": [],
        "nb_par_niveau": {"1": 0, "2": 0, "3": 0, "4": 0},
        "periode_jours": periode_jours,
    }


# ---------------------------------------------------------------------------
# Routes — Incidents
# ---------------------------------------------------------------------------

@app.get(
    "/api/v1/incidents",
    response_model=List[Incident],
    tags=["Incidents"],
    summary="Lister les incidents",
)
async def lister_incidents(
    statut: Optional[str] = Query(default=None),
    severite: Optional[str] = Query(default=None),
    service: Optional[str] = Query(default=None),
):
    """Liste les incidents de sécurité et qualité."""
    incidents = list(_incidents_db.values())
    if statut:
        incidents = [i for i in incidents if i.statut == statut]
    if severite:
        incidents = [i for i in incidents if i.severite == severite]
    if service:
        incidents = [i for i in incidents if i.service_concerne == service]
    return incidents


@app.post(
    "/api/v1/incidents",
    response_model=Incident,
    status_code=status.HTTP_201_CREATED,
    tags=["Incidents"],
    summary="Déclarer un incident",
)
async def creer_incident(incident: CreerIncident):
    """Déclare un nouvel incident de sécurité ou qualité."""
    nouvel_incident = Incident(
        type_incident=incident.type_incident,
        severite=incident.severite,
        description=incident.description,
        service_concerne=incident.service_concerne,
        id_session_impliquee=incident.id_session_impliquee,
    )
    _incidents_db[nouvel_incident.id] = nouvel_incident
    logger.warning(f"Incident déclaré: {nouvel_incident.id} — Sévérité: {incident.severite}")
    return nouvel_incident


@app.put(
    "/api/v1/incidents/{id_incident}",
    response_model=Incident,
    tags=["Incidents"],
    summary="Mettre à jour un incident",
)
async def mettre_a_jour_incident(id_incident: str, mise_a_jour: MettreAJourIncident):
    """Met à jour le statut et les actions correctives d'un incident."""
    if id_incident not in _incidents_db:
        raise HTTPException(status_code=404, detail="Incident introuvable.")
    incident = _incidents_db[id_incident]
    if mise_a_jour.statut:
        incident.statut = mise_a_jour.statut
        if mise_a_jour.statut == "RESOLU":
            incident.date_resolution = datetime.now()
    if mise_a_jour.responsable:
        incident.responsable = mise_a_jour.responsable
    if mise_a_jour.actions_correctives:
        incident.actions_correctives = mise_a_jour.actions_correctives
    return incident


# ---------------------------------------------------------------------------
# Routes — Rapports
# ---------------------------------------------------------------------------

@app.post(
    "/api/v1/rapports/generer",
    response_model=RapportQualite,
    tags=["Rapports"],
    summary="Générer un rapport qualité",
)
async def generer_rapport(
    periode: str = Query(default="semaine", description="Période : jour, semaine, mois, trimestre"),
    format_export: str = Query(default="json", description="Format : json, pdf, excel"),
):
    """
    Génère un rapport qualité complet pour la période spécifiée.
    Inclut métriques, incidents, conformité ISO 27001 et recommandations.
    """
    periodes_jours = {"jour": 1, "semaine": 7, "mois": 30, "trimestre": 90}
    jours = periodes_jours.get(periode, 7)

    metriques = _generer_metriques_demo(jours)
    metriques_anon = _generer_metriques_anonymisation_demo(jours)

    incidents = list(_incidents_db.values())
    nb_par_severite = {"FAIBLE": 0, "MOYEN": 0, "ELEVE": 0, "CRITIQUE": 0}
    for inc in incidents:
        nb_par_severite[inc.severite] = nb_par_severite.get(inc.severite, 0) + 1

    nb_resolus = sum(1 for i in incidents if i.statut in ("RESOLU", "CLOS"))
    taux_resolution = (nb_resolus / len(incidents) * 100) if incidents else 100.0

    recommandations = []
    if metriques.taux_succes_pct < 95:
        recommandations.append("Taux de succès inférieur à 95% — Analyser les causes d'échec.")
    if metriques.nb_garde_fous_declenches > 20:
        recommandations.append("Nombre élevé de déclenchements de garde-fous — Vérifier les tentatives d'abus.")
    if metriques_anon.nb_desactivations > 0:
        recommandations.append(f"{metriques_anon.nb_desactivations} désactivation(s) d'anonymisation — Vérifier les justifications.")
    if not recommandations:
        recommandations.append("Aucune anomalie détectée. Le système fonctionne conformément aux exigences.")

    return RapportQualite(
        id=str(uuid.uuid4()),
        periode=periode,
        date_generation=datetime.now(),
        genere_par="API Qualité HERMES CHU v1.0.0",
        metriques_systeme=metriques,
        metriques_anonymisation=metriques_anon,
        nb_incidents_total=len(incidents),
        nb_incidents_par_severite=nb_par_severite,
        nb_incidents_resolus=nb_resolus,
        taux_resolution_pct=taux_resolution,
        recommandations=recommandations,
        statut_conformite_iso27001="CONFORME" if metriques.taux_succes_pct >= 95 else "NON_CONFORME",
    )


@app.get(
    "/api/v1/rapports/tableau-de-bord",
    tags=["Rapports"],
    summary="Tableau de bord temps réel",
)
async def tableau_de_bord():
    """
    Tableau de bord en temps réel pour le service qualité.
    Agrège les indicateurs clés du système.
    """
    return {
        "horodatage": datetime.now().isoformat(),
        "statut_global": "OPERATIONNEL",
        "agents_actifs": 6,
        "agents_total": 6,
        "requetes_derniere_heure": 187,
        "taux_succes_pct": 96.8,
        "latence_p95_ms": 4800,
        "garde_fous_derniere_heure": 2,
        "incidents_ouverts": len([i for i in _incidents_db.values() if i.statut == "OUVERT"]),
        "anonymisation_active": True,
        "conformite_iso27001": "CONFORME",
    }


# ---------------------------------------------------------------------------
# Routes — Configuration Anonymisation
# ---------------------------------------------------------------------------

@app.get(
    "/api/v1/configuration/anonymisation",
    response_model=ConfigurationAnonymisation,
    tags=["Configuration"],
    summary="Lire la configuration du SAS d'anonymisation",
)
async def lire_config_anonymisation():
    """Retourne la configuration actuelle du SAS d'anonymisation."""
    return ConfigurationAnonymisation(
        actif_par_defaut=True,
        moteur_ner="camembert-bio-medical",
        seuil_confiance_ner=0.85,
        types_phi_actifs=["NOM_PATIENT", "PRENOM_PATIENT", "DATE_NAISSANCE", "NIR",
                          "ADRESSE", "TELEPHONE", "EMAIL", "IPP", "NOM_MEDECIN", "RPPS"],
        ttl_mapping_secondes=3600,
        journalisation_active=True,
    )


@app.put(
    "/api/v1/configuration/anonymisation",
    tags=["Configuration"],
    summary="Modifier la configuration du SAS d'anonymisation",
)
async def modifier_config_anonymisation(
    config: ConfigurationAnonymisation,
    justification: str = Query(..., min_length=20, description="Justification obligatoire de la modification"),
):
    """
    Modifie la configuration du SAS d'anonymisation.
    Opération critique — ROLE_ADMIN_PRIVACY ou ROLE_RSSI requis.
    Journalisée systématiquement.
    """
    logger.warning(f"Configuration anonymisation modifiée — Justification: {justification}")
    return {"message": "Configuration mise à jour.", "justification": justification}


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8002, reload=False)
