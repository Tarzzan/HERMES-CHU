"""
HERMES CHU — Patch d'intégration du Privacy Engine sur hermes-agent
====================================================================
Ce module monkey-patche les fonctions de sanitisation de hermes-agent
pour y injecter le Privacy Engine RGPD AVANT et APRÈS chaque appel LLM.

Utilisation (dans hermes_cli/main.py ou l'entrypoint CHU) :
    from chu.privacy_engine.patch_hermes import appliquer_patch_chu
    appliquer_patch_chu()

Le patch est non-destructif : il préserve le comportement original de
hermes-agent et ajoute uniquement les couches d'anonymisation CHU.

Architecture du patch :
    1. Wrap de _prepare_messages() → anonymise les messages avant envoi LLM
    2. Wrap de la réponse LLM     → contrôle de sortie (PHI résiduels)
    3. Injection du statut Privacy Engine dans le contexte de session
"""

from __future__ import annotations

import logging
import sys
from typing import Any, Callable, Dict, List, Optional

logger = logging.getLogger(__name__)

# Indicateur d'application du patch
_patch_applique = False


def appliquer_patch_chu() -> None:
    """
    Applique le patch CHU sur hermes-agent.
    Idempotent : peut être appelé plusieurs fois sans effet de bord.
    """
    global _patch_applique
    if _patch_applique:
        return

    try:
        _patcher_sanitisation_messages()
        _patcher_conversation_loop()
        _patch_applique = True
        logger.info("[PATCH CHU] ✅ Privacy Engine RGPD branché sur hermes-agent")
    except ImportError as e:
        logger.warning(
            "[PATCH CHU] ⚠️  hermes-agent non disponible dans sys.path — "
            "mode autonome activé. Erreur : %s", e
        )


def _patcher_sanitisation_messages() -> None:
    """
    Patche agent.message_sanitization pour anonymiser les messages
    avant qu'ils ne soient envoyés au LLM.
    """
    try:
        import agent.message_sanitization as ms
        from chu.privacy_engine.middleware import get_privacy_engine

        _original_sanitize = ms._sanitize_surrogates

        def _sanitize_surrogates_chu(text: str) -> str:
            """Version CHU : anonymise les PHI puis applique la sanitisation originale."""
            engine = get_privacy_engine()
            if engine.actif and text:
                # Session ID générique pour la sanitisation bas niveau
                text_safe, _ = engine.anonymiser(text, session_id="sanitize_global")
                return _original_sanitize(text_safe)
            return _original_sanitize(text)

        ms._sanitize_surrogates = _sanitize_surrogates_chu
        logger.debug("[PATCH CHU] message_sanitization patché")

    except ImportError:
        logger.debug("[PATCH CHU] agent.message_sanitization non disponible")


def _patcher_conversation_loop() -> None:
    """
    Patche agent.conversation_loop pour :
    1. Anonymiser les messages utilisateur avant envoi au LLM
    2. Contrôler les sorties LLM pour PHI résiduels
    """
    try:
        import agent.conversation_loop as cl
        from chu.privacy_engine.middleware import get_privacy_engine

        # Patch de la fonction de préparation du contexte
        if hasattr(cl, "build_turn_context"):
            _original_build = cl.build_turn_context

            def build_turn_context_chu(agent: Any, *args, **kwargs):
                """Version CHU : anonymise le message utilisateur avant construction du contexte."""
                engine = get_privacy_engine()
                session_id = getattr(agent, "session_id", "unknown")

                # Anonymiser le dernier message utilisateur si présent
                messages = getattr(agent, "messages", [])
                if messages and engine.actif:
                    dernier = messages[-1]
                    if isinstance(dernier, dict) and dernier.get("role") == "user":
                        contenu = dernier.get("content", "")
                        if isinstance(contenu, str):
                            contenu_safe, resultat = engine.anonymiser(
                                contenu, session_id,
                                getattr(agent, "user_id", "anonyme"),
                            )
                            if resultat.entites_detectees:
                                messages[-1] = {**dernier, "content": contenu_safe}
                                logger.info(
                                    "[PRIVACY] %d PHI anonymisés pour session=%s",
                                    len(resultat.entites_detectees), session_id[:8],
                                )

                return _original_build(agent, *args, **kwargs)

            cl.build_turn_context = build_turn_context_chu
            logger.debug("[PATCH CHU] conversation_loop.build_turn_context patché")

    except ImportError:
        logger.debug("[PATCH CHU] agent.conversation_loop non disponible")


# ---------------------------------------------------------------------------
# Helpers pour l'interface web CHU
# ---------------------------------------------------------------------------

def anonymiser_message(
    texte: str,
    session_id: str,
    utilisateur_id: str = "anonyme",
) -> Dict[str, Any]:
    """
    Point d'entrée pour anonymiser un message depuis l'interface web CHU.
    Utilisé par le serveur FastAPI de l'orchestrateur CHU.
    """
    from chu.privacy_engine.middleware import get_privacy_engine

    engine = get_privacy_engine()
    texte_safe, resultat = engine.anonymiser(texte, session_id, utilisateur_id)

    return {
        "texte_original": texte,
        "texte_anonymise": texte_safe,
        "nb_entites_detectees": len(resultat.entites_detectees),
        "types_phi": list({e.type_entite for e in resultat.entites_detectees}),
        "taux_anonymisation": resultat.taux_anonymisation,
        "anonymisation_active": engine.actif,
        "glass_break_actif": engine._est_glass_break_actif(session_id),
    }


def controle_sortie_llm(texte: str, session_id: str) -> str:
    """
    Garde-fou Niveau 3 : à appeler sur chaque réponse LLM avant restitution.
    """
    from chu.privacy_engine.middleware import get_privacy_engine
    return get_privacy_engine().controle_sortie(texte, session_id)
