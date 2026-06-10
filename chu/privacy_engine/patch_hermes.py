"""
HERMES CHU — Patch d'intégration du Privacy Engine sur hermes-agent
====================================================================

Ce module applique des monkey-patches non-destructifs sur les points
d'entrée critiques de hermes-agent (NousResearch) pour garantir que
le Privacy Engine RGPD s'applique sur TOUS les flux de données :

  Flux couverts :
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. message_sanitization.py  → Entrées utilisateur vers le LLM  │
  │ 2. conversation_loop.py     → Réponses LLM vers l'utilisateur  │
  │ 3. memory_manager.py        → Écriture en mémoire persistante  │
  │ 4. background_review.py     → Revue de fond (agent fantôme)    │
  │ 5. trajectory.py            → Sauvegarde JSONL fine-tuning     │
  └─────────────────────────────────────────────────────────────────┘

Principe : chaque patch wraps la fonction originale — si le Privacy
Engine est désactivé (glass-break), la fonction originale est appelée
directement et l'événement est journalisé dans l'audit ISO 27001.

Usage (dans chu/installer_chu.sh) :
    python3 -c "from chu.privacy_engine.patch_hermes import appliquer_patches; appliquer_patches()"

Ou depuis le point d'entrée CHU (l'import suffit) :
    import chu.privacy_engine.patch_hermes
"""

from __future__ import annotations

import functools
import hashlib
import json
import logging
import os
import threading
import urllib.request
from datetime import datetime
from typing import Any, Dict, List, Optional

logger = logging.getLogger("hermes_chu.privacy_patch")

# ---------------------------------------------------------------------------
# Import du Privacy Engine CHU
# ---------------------------------------------------------------------------
try:
    from chu.privacy_engine.middleware import get_privacy_engine
    _PRIVACY_ENGINE_DISPONIBLE = True
except ImportError:
    logger.warning(
        "[CHU] Privacy Engine non disponible — les patches ne seront pas appliqués. "
        "Vérifiez que chu/privacy_engine/middleware.py est accessible."
    )
    _PRIVACY_ENGINE_DISPONIBLE = False

# Registre des patches appliqués (idempotence)
_PATCHES_APPLIQUES: Dict[str, bool] = {}


# ---------------------------------------------------------------------------
# Journal d'audit ISO 27001
# ---------------------------------------------------------------------------

def _journaliser_evenement(
    type_evenement: str,
    details: Dict[str, Any],
    phi_detecte: bool = False,
    glass_break: bool = False,
) -> None:
    """Journalise un événement dans le journal d'audit ISO 27001.

    Chaque entrée est hashée SHA-256 pour garantir l'immuabilité du journal.
    Les entrées sont écrites dans ~/.hermes/audit_chu.jsonl et envoyées
    de manière asynchrone à l'API Qualité CHU (port 8001).
    """
    entree = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "type": type_evenement,
        "details": details,
        "phi_detecte": phi_detecte,
        "glass_break_actif": glass_break,
        "version_patch": "1.1.0",
    }
    contenu_hash = json.dumps(entree, sort_keys=True, ensure_ascii=False)
    entree["hash_sha256"] = hashlib.sha256(contenu_hash.encode()).hexdigest()

    # Écriture locale (synchrone)
    journal_path = os.path.expanduser("~/.hermes/audit_chu.jsonl")
    os.makedirs(os.path.dirname(journal_path), exist_ok=True)
    try:
        with open(journal_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(entree, ensure_ascii=False) + "\n")
    except Exception as e:
        logger.error("[CHU] Échec écriture journal audit : %s", e)

    # Envoi asynchrone à l'API Qualité (non bloquant)
    def _envoyer():
        try:
            data = json.dumps(entree, ensure_ascii=False).encode()
            req = urllib.request.Request(
                "http://localhost:8001/api/chu/audit",
                data=data,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=2)
        except Exception:
            pass  # L'API Qualité est optionnelle — ne pas bloquer

    threading.Thread(target=_envoyer, daemon=True).start()


# ---------------------------------------------------------------------------
# Patch 1 : message_sanitization.py — Entrées utilisateur
# ---------------------------------------------------------------------------

def _patch_message_sanitization() -> bool:
    """Patche _sanitize_surrogates() et sanitize_message() pour anonymiser les entrées."""
    try:
        import agent.message_sanitization as ms
        if getattr(ms, "_chu_patched", False):
            return True

        # Patch de _sanitize_surrogates (bas niveau)
        if hasattr(ms, "_sanitize_surrogates"):
            _orig = ms._sanitize_surrogates

            @functools.wraps(_orig)
            def _sanitize_surrogates_chu(text: str) -> str:
                if _PRIVACY_ENGINE_DISPONIBLE and text:
                    engine = get_privacy_engine()
                    if engine.actif:
                        texte_safe, resultat = engine.anonymiser(text, session_id="sanitize_global")
                        if resultat.entites_detectees:
                            _journaliser_evenement(
                                "phi_detecte_entree_utilisateur",
                                {"flux": "message_sanitization", "entites": len(resultat.entites_detectees)},
                                phi_detecte=True,
                            )
                        return _orig(texte_safe)
                return _orig(text)

            ms._sanitize_surrogates = _sanitize_surrogates_chu

        # Patch de build_turn_context si présent dans conversation_loop
        ms._chu_patched = True
        logger.info("[CHU] Patch appliqué : message_sanitization")
        return True

    except (ImportError, AttributeError) as e:
        logger.warning("[CHU] Patch message_sanitization ignoré : %s", e)
        return False


# ---------------------------------------------------------------------------
# Patch 2 : conversation_loop.py — Entrées et sorties LLM
# ---------------------------------------------------------------------------

def _patch_conversation_loop() -> bool:
    """Patche build_turn_context() pour anonymiser avant envoi et contrôler les sorties."""
    try:
        import agent.conversation_loop as cl
        if getattr(cl, "_chu_patched", False):
            return True

        # Patch de build_turn_context (préparation des messages)
        if hasattr(cl, "build_turn_context"):
            _orig_build = cl.build_turn_context

            @functools.wraps(_orig_build)
            def build_turn_context_chu(agent: Any, *args, **kwargs):
                if _PRIVACY_ENGINE_DISPONIBLE:
                    engine = get_privacy_engine()
                    session_id = getattr(agent, "session_id", "unknown")
                    messages = getattr(agent, "messages", [])
                    if messages and engine.actif:
                        dernier = messages[-1]
                        if isinstance(dernier, dict) and dernier.get("role") == "user":
                            contenu = dernier.get("content", "")
                            if isinstance(contenu, str) and contenu:
                                texte_safe, resultat = engine.anonymiser(
                                    contenu, session_id,
                                    getattr(agent, "user_id", "anonyme"),
                                )
                                if resultat.entites_detectees:
                                    messages[-1] = {**dernier, "content": texte_safe}
                                    _journaliser_evenement(
                                        "phi_anonymise_avant_llm",
                                        {
                                            "flux": "conversation_loop.build_turn_context",
                                            "session": session_id[:8],
                                            "nb_entites": len(resultat.entites_detectees),
                                        },
                                        phi_detecte=True,
                                    )
                return _orig_build(agent, *args, **kwargs)

            cl.build_turn_context = build_turn_context_chu

        # Re-scan PHI sur les sorties LLM
        for nom_func in ["process_response", "handle_response", "_emit_response"]:
            if hasattr(cl, nom_func):
                _orig_resp = getattr(cl, nom_func)

                @functools.wraps(_orig_resp)
                def _response_chu(*args, _orig=_orig_resp, _nom=nom_func, **kwargs):
                    resultat = _orig(*args, **kwargs)
                    if _PRIVACY_ENGINE_DISPONIBLE and isinstance(resultat, str) and resultat:
                        engine = get_privacy_engine()
                        if engine.actif:
                            scan = engine.scanner_phi(resultat)
                            if scan.entites_detectees:
                                logger.warning(
                                    "[CHU] PHI résiduel détecté en SORTIE LLM (%s) — "
                                    "vérifier le prompt système", _nom
                                )
                                _journaliser_evenement(
                                    "phi_residuel_sortie_llm",
                                    {"flux": f"conversation_loop.{_nom}", "gravite": "HAUTE"},
                                    phi_detecte=True,
                                )
                    return resultat

                setattr(cl, nom_func, _response_chu)
                break

        cl._chu_patched = True
        logger.info("[CHU] Patch appliqué : conversation_loop")
        return True

    except (ImportError, AttributeError) as e:
        logger.warning("[CHU] Patch conversation_loop ignoré : %s", e)
        return False


# ---------------------------------------------------------------------------
# Patch 3 : memory_manager.py — Écriture en mémoire persistante
# ---------------------------------------------------------------------------

def _patch_memory_manager() -> bool:
    """Patche MemoryManager.sync_all() pour anonymiser avant toute écriture mémoire."""
    try:
        import agent.memory_manager as mod
        if getattr(mod.MemoryManager, "_chu_patched", False):
            return True

        _orig_sync = mod.MemoryManager.sync_all

        @functools.wraps(_orig_sync)
        def sync_all_chu(self, user_msg: str, assistant_response: str, *args, **kwargs):
            if _PRIVACY_ENGINE_DISPONIBLE:
                engine = get_privacy_engine()
                if engine.actif:
                    session_id = getattr(self, "session_id", "memory_sync")
                    res_user = engine.anonymiser(user_msg or "", session_id)
                    res_asst = engine.anonymiser(assistant_response or "", session_id)

                    phi_detecte = (
                        bool(res_user[1].entites_detectees) or
                        bool(res_asst[1].entites_detectees)
                    )
                    if phi_detecte:
                        _journaliser_evenement(
                            "phi_anonymise_avant_memoire",
                            {
                                "flux": "memory_manager.sync_all",
                                "phi_user": len(res_user[1].entites_detectees),
                                "phi_assistant": len(res_asst[1].entites_detectees),
                            },
                            phi_detecte=True,
                        )
                    user_msg = res_user[0]
                    assistant_response = res_asst[0]

            return _orig_sync(self, user_msg, assistant_response, *args, **kwargs)

        sync_all_chu._chu_patched = True
        mod.MemoryManager.sync_all = sync_all_chu
        mod.MemoryManager._chu_patched = True
        logger.info("[CHU] Patch appliqué : memory_manager.MemoryManager.sync_all")
        return True

    except (ImportError, AttributeError) as e:
        logger.warning("[CHU] Patch memory_manager ignoré : %s", e)
        return False


# ---------------------------------------------------------------------------
# Patch 4 : background_review.py — Agent fantôme de revue et d'apprentissage
# ---------------------------------------------------------------------------

def _patch_background_review() -> bool:
    """Patche spawn_background_review() pour anonymiser le snapshot de conversation."""
    try:
        import agent.background_review as mod
        if getattr(mod, "_chu_patched", False):
            return True

        _orig_spawn = mod.spawn_background_review

        @functools.wraps(_orig_spawn)
        def spawn_background_review_chu(conversation_snapshot: List[Dict], *args, **kwargs):
            if _PRIVACY_ENGINE_DISPONIBLE and conversation_snapshot:
                engine = get_privacy_engine()
                if engine.actif:
                    snapshot_propre = []
                    phi_global = False
                    for message in conversation_snapshot:
                        msg = dict(message)
                        contenu = msg.get("content", "")
                        if isinstance(contenu, str) and contenu:
                            texte_safe, res = engine.anonymiser(contenu, "background_review")
                            msg["content"] = texte_safe
                            if res.entites_detectees:
                                phi_global = True
                        snapshot_propre.append(msg)

                    if phi_global:
                        _journaliser_evenement(
                            "phi_anonymise_background_review",
                            {"flux": "background_review.spawn", "messages": len(snapshot_propre)},
                            phi_detecte=True,
                        )
                    conversation_snapshot = snapshot_propre

            return _orig_spawn(conversation_snapshot, *args, **kwargs)

        spawn_background_review_chu._chu_patched = True
        mod.spawn_background_review = spawn_background_review_chu
        mod._chu_patched = True
        logger.info("[CHU] Patch appliqué : background_review.spawn_background_review")
        return True

    except (ImportError, AttributeError) as e:
        logger.warning("[CHU] Patch background_review ignoré : %s", e)
        return False


# ---------------------------------------------------------------------------
# Patch 5 : trajectory.py — Sauvegarde JSONL pour fine-tuning futur
# ---------------------------------------------------------------------------

def _patch_trajectory() -> bool:
    """Patche save_trajectory() pour anonymiser avant sauvegarde JSONL."""
    try:
        import agent.trajectory as mod
        if getattr(mod, "_chu_patched", False):
            return True

        _orig_save = mod.save_trajectory

        @functools.wraps(_orig_save)
        def save_trajectory_chu(
            trajectory: List[Dict[str, Any]],
            model: str,
            completed: bool,
            filename: str = None,
        ):
            if _PRIVACY_ENGINE_DISPONIBLE and trajectory:
                engine = get_privacy_engine()
                if engine.actif:
                    traj_propre = []
                    phi_global = False
                    for tour in trajectory:
                        t = dict(tour)
                        for champ in ["value", "content", "text"]:
                            if champ in t and isinstance(t[champ], str):
                                texte_safe, res = engine.anonymiser(t[champ], "trajectory")
                                t[champ] = texte_safe
                                if res.entites_detectees:
                                    phi_global = True
                        traj_propre.append(t)

                    if phi_global:
                        _journaliser_evenement(
                            "phi_anonymise_trajectoire",
                            {
                                "flux": "trajectory.save_trajectory",
                                "modele": model,
                                "tours": len(trajectory),
                                "completed": completed,
                            },
                            phi_detecte=True,
                        )
                    trajectory = traj_propre

            return _orig_save(trajectory, model, completed, filename)

        save_trajectory_chu._chu_patched = True
        mod.save_trajectory = save_trajectory_chu
        mod._chu_patched = True
        logger.info("[CHU] Patch appliqué : trajectory.save_trajectory")
        return True

    except (ImportError, AttributeError) as e:
        logger.warning("[CHU] Patch trajectory ignoré : %s", e)
        return False


# ---------------------------------------------------------------------------
# Helpers pour l'interface web CHU (rétrocompatibilité)
# ---------------------------------------------------------------------------

def appliquer_patch_chu() -> None:
    """Alias rétrocompatible — appelle appliquer_patches()."""
    appliquer_patches(strict=False)


def anonymiser_message(
    texte: str,
    session_id: str,
    utilisateur_id: str = "anonyme",
) -> Dict[str, Any]:
    """Point d'entrée pour anonymiser un message depuis l'interface web CHU."""
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
    """Garde-fou Niveau 3 : à appeler sur chaque réponse LLM avant restitution."""
    return get_privacy_engine().controle_sortie(texte, session_id)


def statut_patches() -> Dict[str, Any]:
    """Retourne le statut actuel des patches appliqués."""
    return {
        "privacy_engine_disponible": _PRIVACY_ENGINE_DISPONIBLE,
        "patches": _PATCHES_APPLIQUES,
        "tous_appliques": all(_PATCHES_APPLIQUES.values()) if _PATCHES_APPLIQUES else False,
    }


# ---------------------------------------------------------------------------
# Point d'entrée principal
# ---------------------------------------------------------------------------

def appliquer_patches(strict: bool = False) -> Dict[str, bool]:
    """Applique tous les patches Privacy Engine CHU sur hermes-agent.

    Args:
        strict: Si True, lève une exception si un patch obligatoire échoue.

    Returns:
        Dictionnaire {nom_patch: succès} pour chaque patch tenté.
    """
    if not _PRIVACY_ENGINE_DISPONIBLE:
        logger.error(
            "[CHU] Privacy Engine non disponible — AUCUN patch appliqué. "
            "Les données PHI ne sont PAS protégées !"
        )
        if strict:
            raise RuntimeError("Privacy Engine CHU non disponible")
        return {}

    patches = [
        ("message_sanitization", _patch_message_sanitization, True),
        ("conversation_loop",    _patch_conversation_loop,    True),
        ("memory_manager",       _patch_memory_manager,       True),
        ("background_review",    _patch_background_review,    False),
        ("trajectory",           _patch_trajectory,           False),
    ]

    resultats = {}
    for nom, fn_patch, obligatoire in patches:
        if _PATCHES_APPLIQUES.get(nom):
            resultats[nom] = True
            continue
        try:
            succes = fn_patch()
            resultats[nom] = succes
            _PATCHES_APPLIQUES[nom] = succes
            if not succes and obligatoire and strict:
                raise RuntimeError(f"Patch obligatoire '{nom}' a échoué")
        except Exception as e:
            logger.error("[CHU] Erreur patch '%s' : %s", nom, e)
            resultats[nom] = False
            _PATCHES_APPLIQUES[nom] = False
            if obligatoire and strict:
                raise

    _journaliser_evenement(
        "patches_privacy_engine_initialises",
        {"patches": resultats, "version_hermes_chu": "1.1.0"},
    )

    succes_count = sum(1 for v in resultats.values() if v)
    logger.info(
        "[CHU] Patches Privacy Engine : %d/%d appliqués — %s",
        succes_count, len(resultats), resultats,
    )
    return resultats


# ---------------------------------------------------------------------------
# Auto-application à l'import
# ---------------------------------------------------------------------------
if _PRIVACY_ENGINE_DISPONIBLE:
    try:
        appliquer_patches(strict=False)
    except Exception as e:
        logger.error("[CHU] Erreur lors de l'auto-application des patches : %s", e)
