# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Banc de Recette
=========================
Console web LAN pour la recette des livrables PULSAR (installateurs, releases).

Hébergée sur le poste de développement (Abux), accessible depuis les postes
de test du LAN. Les testeurs y déposent logs et captures d'écran (Ctrl+V),
suivent la checklist de recette et lisent les réponses de l'assistant qui
surveille l'inbox en temps réel.

Lancement :
    python3 recette/serveur_recette.py          # port 9333

Stockage (plat, exploitable sans le serveur) :
    recette/inbox/<ticket>/meta.json + message.txt + fichiers collés
    recette/reponses/<ticket>.md     ← réponses de l'assistant
    recette/checklist.json           ← état des scénarios de recette
    recette/PV-recette-<date>.md     ← procès-verbal exporté
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import secrets
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import (FileResponse, HTMLResponse, JSONResponse,
                               PlainTextResponse, RedirectResponse)
from pydantic import BaseModel

import auth  # PULSAR Ops — authentification locale (mot de passe + TOTP + RBAC)

COOKIE = "pulsar_session"
PUBLIC = ("/login", "/setup", "/setup/totp", "/logout", "/favicon.ico")

RACINE = Path(__file__).parent
INBOX = RACINE / "inbox"
REPONSES = RACINE / "reponses"
CHECKLIST_FICHIER = RACINE / "checklist.json"
COMMANDES = RACINE / "commandes"
TOKEN_FICHIER = RACINE / "agent-token.txt"
MODE_FICHIER = RACINE / "mode.json"
REGISTRE = RACINE / "registre-actions.jsonl"

VERSION_RECETTE = "PULSAR-Setup-2.3.1"

# Modes de gouvernance de l'exécution distante :
#   autonome — l'agent exécute automatiquement les commandes proposées (dev).
#   hybride  — chaque commande attend une APPROBATION humaine avant l'agent.
#   pilote   — l'agent n'exécute RIEN ; l'admin copie-colle et exécute lui-même,
#              puis recolle la sortie. Validation 100 % humaine (prod / ISO 27001).
MODES = ("autonome", "hybride", "pilote")

SCENARIOS_DEFAUT = [
    {"id": "sha256", "titre": "SHA256 de l'exe vérifié (e973369b…97)", "statut": "en_attente", "commentaire": ""},
    {"id": "complete", "titre": "Installation complète (CLI + Web + Desktop)", "statut": "en_attente", "commentaire": ""},
    {"id": "cli-web", "titre": "Installation CLI / Web uniquement", "statut": "en_attente", "commentaire": ""},
    {"id": "desktop", "titre": "Installation Desktop uniquement", "statut": "en_attente", "commentaire": ""},
    {"id": "raccourcis", "titre": "Raccourcis Bureau créés et fonctionnels", "statut": "en_attente", "commentaire": ""},
    {"id": "dashboard", "titre": "Dashboard web accessible (localhost:9119)", "statut": "en_attente", "commentaire": ""},
    {"id": "reparer", "titre": "Mode Réparer (conserve config/sessions)", "statut": "en_attente", "commentaire": ""},
    {"id": "maj", "titre": "Mode Mettre à jour (git pull + rebuild)", "statut": "en_attente", "commentaire": ""},
    {"id": "desinstaller", "titre": "Désinstallation (données ~/.pulsar conservées)", "statut": "en_attente", "commentaire": ""},
]

app = FastAPI(title="PULSAR — Banc de Recette", docs_url="/api/docs")


# ---------------------------------------------------------------------------
# Authentification (PULSAR Ops) — middleware + pages login / setup / 2FA
# ---------------------------------------------------------------------------

@app.middleware("http")
async def _garde(request: Request, call_next):
    """Protège toute la console : seul l'agent (jeton) et les pages d'auth sont
    publics. Première utilisation → /setup. Sinon, session requise."""
    path = request.url.path
    if path.startswith("/api/agent/") or path in PUBLIC:
        return await call_next(request)
    if not auth.has_users():
        return (await call_next(request)) if path == "/setup" else RedirectResponse("/setup", 303)
    sess = auth.read_session(request.cookies.get(COOKIE))
    if not sess or sess.get("r") == "_pending":
        if path.startswith("/api/"):
            return JSONResponse({"detail": "Authentification requise"}, status_code=401)
        return RedirectResponse("/login", 303)
    request.state.user = sess
    return await call_next(request)


def _exiger(request: Request, perm: str) -> dict:
    u = getattr(getattr(request, "state", None), "user", None)
    if not u:
        raise HTTPException(401, "Authentification requise")
    if not auth.can(u["r"], perm):
        raise HTTPException(403, f"Droit insuffisant pour « {perm} »")
    return u


_AUTH_CSS = """<style>
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
font-family:system-ui,'Segoe UI',sans-serif;background:linear-gradient(135deg,#0a1422,#0052cc);color:#1b2330}
.card{background:#fff;border-radius:14px;box-shadow:0 12px 50px rgba(0,0,0,.35);padding:28px 32px;width:390px;max-width:94vw}
.brand{font-weight:700;color:#0052cc;font-size:13px}.brand .cx{color:#EF5350}
h1{font-size:20px;margin:.5em 0 .7em}
label{display:block;font-size:12px;color:#5a6b80;margin:12px 0 4px;font-weight:600}
input{width:100%;padding:10px 12px;border:1px solid #c4ccd6;border-radius:8px;font-size:14px}
input:focus{outline:2px solid #0052cc55;border-color:#0052cc}
button{width:100%;margin-top:18px;background:#0052cc;color:#fff;border:0;border-radius:9px;padding:11px;font-size:15px;cursor:pointer}
button:hover{filter:brightness(1.08)}
.alert{background:#fde2dd;color:#c4321e;border:1px solid #f3c0ba;border-radius:8px;padding:9px 12px;font-size:13px;margin-bottom:8px}
.hint{font-size:12px;color:#5a6b80;margin-top:6px;line-height:1.5}
.secret{font:15px ui-monospace,monospace;background:#f1f5fb;border:1px dashed #9db3d0;border-radius:8px;padding:11px;text-align:center;letter-spacing:2px;word-break:break-all;margin:8px 0}
a{color:#0052cc}
</style>"""


def _auth_html(titre, contenu, alerte=""):
    al = f'<div class="alert">{alerte}</div>' if alerte else ""
    return ("<!doctype html><html lang=fr><head><meta charset=utf-8>"
            "<meta name=viewport content='width=device-width,initial-scale=1'>"
            f"<title>{titre} — PULSAR Ops</title>" + _AUTH_CSS + "</head><body><div class=card>"
            "<div class=\"brand\"><span class=\"cx\">✚</span> PULSAR Ops · Console d'intervention</div>"
            f"<h1>{titre}</h1>{al}{contenu}</div></body></html>")


@app.get("/login", response_class=HTMLResponse)
async def page_login(err: str = ""):
    form = ('<form method="post" action="/login">'
            '<label>Identifiant</label><input name="identifiant" autofocus autocomplete="username">'
            '<label>Mot de passe</label><input name="motdepasse" type="password" autocomplete="current-password">'
            "<label>Code 2FA (6 chiffres)</label>"
            '<input name="code" inputmode="numeric" autocomplete="one-time-code" placeholder="123456">'
            "<button>Se connecter</button></form>")
    return _auth_html("Connexion", form, "Identifiants ou code invalides." if err else "")


@app.post("/login")
async def faire_login(identifiant: str = Form(""), motdepasse: str = Form(""), code: str = Form("")):
    uname = identifiant.strip().lower()
    u = auth.load_users().get(uname)
    ok = bool(u) and auth.verify_password(motdepasse, u["password"])
    if ok and u.get("totp_active"):
        ok = auth.totp_verify(u["totp"], code)
    if not ok:
        _journaliser("connexion_refusee", {"identifiant": uname})
        return RedirectResponse("/login?err=1", 303)
    resp = RedirectResponse("/", 303)
    resp.set_cookie(COOKIE, auth.make_session(uname, u["role"]), httponly=True, samesite="lax", max_age=auth.SESSION_TTL)
    _journaliser("connexion", {"par": uname, "role": u["role"]})
    return resp


@app.get("/logout")
async def faire_logout(request: Request):
    sess = auth.read_session(request.cookies.get(COOKIE))
    if sess:
        _journaliser("deconnexion", {"par": sess.get("u")})
    resp = RedirectResponse("/login", 303)
    resp.delete_cookie(COOKIE)
    return resp


@app.get("/setup", response_class=HTMLResponse)
async def page_setup(err: str = ""):
    if auth.has_users():
        return RedirectResponse("/login", 303)
    form = ('<p class="hint">Première utilisation : créez le compte administrateur. '
            "L'étape suivante configurera la double authentification (2FA).</p>"
            '<form method="post" action="/setup">'
            '<label>Identifiant admin</label><input name="identifiant" autofocus value="admin">'
            '<label>Mot de passe (8 caractères min.)</label><input name="motdepasse" type="password">'
            '<label>Confirmer</label><input name="confirm" type="password">'
            "<button>Créer le compte → 2FA</button></form>")
    return _auth_html("Configuration initiale", form,
                      "Mot de passe trop court ou non concordant." if err else "")


@app.post("/setup")
async def faire_setup(identifiant: str = Form(""), motdepasse: str = Form(""), confirm: str = Form("")):
    if auth.has_users():
        return RedirectResponse("/login", 303)
    if len(motdepasse) < 8 or motdepasse != confirm:
        return RedirectResponse("/setup?err=1", 303)
    uname = identifiant.strip().lower() or "admin"
    secret = auth.totp_new_secret()
    auth.create_user(uname, motdepasse, role="admin", totp_secret=secret)
    _journaliser("compte_admin_initie", {"par": uname})
    resp = RedirectResponse("/setup/totp", 303)
    resp.set_cookie(COOKIE, auth.make_session(uname, "_pending", ttl=600), httponly=True, samesite="lax", max_age=600)
    return resp


@app.get("/setup/totp", response_class=HTMLResponse)
async def page_totp(request: Request, err: str = ""):
    sess = auth.read_session(request.cookies.get(COOKIE))
    if not sess or sess.get("r") != "_pending":
        return RedirectResponse("/login", 303)
    u = auth.load_users().get(sess["u"])
    if not u:
        return RedirectResponse("/setup", 303)
    uri = auth.totp_uri(u["totp"], sess["u"]).replace("&", "&amp;")
    contenu = ("<p class=\"hint\">Ouvrez votre application d'authentification "
               "(Google&nbsp;Authenticator, Microsoft&nbsp;Authenticator, Authy…), ajoutez un compte par "
               "<b>saisie manuelle de la clé</b> ci-dessous, puis entrez le code à 6 chiffres généré.</p>"
               '<label>Clé de configuration (Base32)</label>'
               f'<div class="secret">{u["totp"]}</div>'
               f'<p class="hint">Compte&nbsp;: <b>{sess["u"]}</b> · Émetteur&nbsp;: <b>PULSAR Ops</b> · '
               f'6 chiffres / 30&nbsp;s · <a href="{uri}">lien otpauth (mobile)</a></p>'
               '<form method="post" action="/setup/totp">'
               '<label>Code à 6 chiffres</label>'
               '<input name="code" inputmode="numeric" autofocus placeholder="123456">'
               "<button>Activer la 2FA et entrer</button></form>")
    return _auth_html("Double authentification (2FA)", contenu,
                      "Code incorrect, réessayez." if err else "")


@app.post("/setup/totp")
async def faire_totp(request: Request, code: str = Form("")):
    sess = auth.read_session(request.cookies.get(COOKIE))
    if not sess or sess.get("r") != "_pending":
        return RedirectResponse("/login", 303)
    u = auth.load_users().get(sess["u"])
    if not u or not auth.totp_verify(u["totp"], code):
        return RedirectResponse("/setup/totp?err=1", 303)
    auth.set_totp(sess["u"], u["totp"], active=True)
    _journaliser("compte_admin_cree", {"par": sess["u"], "2fa": "activee"})
    resp = RedirectResponse("/", 303)
    resp.set_cookie(COOKIE, auth.make_session(sess["u"], "admin"), httponly=True, samesite="lax", max_age=auth.SESSION_TTL)
    return resp



# ---------------------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------------------

def _charger_checklist() -> List[dict]:
    if CHECKLIST_FICHIER.exists():
        return json.loads(CHECKLIST_FICHIER.read_text(encoding="utf-8"))
    CHECKLIST_FICHIER.write_text(
        json.dumps(SCENARIOS_DEFAUT, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return json.loads(json.dumps(SCENARIOS_DEFAUT))


def _nom_sur(nom: str) -> str:
    nom = re.sub(r"[^A-Za-z0-9._-]", "_", nom or "fichier")
    return nom[:80] or "fichier"


def _lister_tickets() -> List[dict]:
    tickets = []
    for d in sorted(INBOX.iterdir(), reverse=True):
        meta_f = d / "meta.json"
        if not d.is_dir() or not meta_f.exists():
            continue
        meta = json.loads(meta_f.read_text(encoding="utf-8"))
        rep_f = REPONSES / f"{d.name}.md"
        meta["reponse"] = rep_f.read_text(encoding="utf-8") if rep_f.exists() else None
        meta["statut"] = "répondu" if meta["reponse"] else "nouveau"
        meta["fichiers"] = sorted(
            f.name for f in d.iterdir() if f.name not in ("meta.json", "message.txt")
        )
        msg_f = d / "message.txt"
        meta["message"] = msg_f.read_text(encoding="utf-8") if msg_f.exists() else ""
        tickets.append(meta)
    return tickets


def _ecrire_ticket(message, scenario, machine, fichiers=(), extra=None):
    """Crée un ticket sur disque. fichiers = liste de (nom, octets).
    meta.json est écrit en DERNIER : signal 'ticket complet' pour le moniteur."""
    horodatage = datetime.now()
    ticket_id = f"T{horodatage:%Y%m%d-%H%M%S}-{secrets.token_hex(2)}"
    dossier = INBOX / ticket_id
    dossier.mkdir(parents=True)

    noms = []
    for nom, contenu in fichiers:
        if len(contenu) > 25 * 1024 * 1024:
            continue  # garde-fou 25 Mo par fichier
        nom = _nom_sur(nom)
        (dossier / nom).write_bytes(contenu)
        noms.append(nom)

    if message and message.strip():
        (dossier / "message.txt").write_text(message, encoding="utf-8")

    meta = {
        "id": ticket_id,
        "horodatage": horodatage.isoformat(timespec="seconds"),
        "machine": machine or "inconnue",
        "scenario": scenario or "",
        "version": VERSION_RECETTE,
    }
    if extra:
        meta.update(extra)
    (dossier / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return ticket_id, noms


def _token() -> str:
    if TOKEN_FICHIER.exists():
        return TOKEN_FICHIER.read_text(encoding="utf-8").strip()
    t = secrets.token_urlsafe(24)
    TOKEN_FICHIER.write_text(t, encoding="utf-8")
    return t


# ---------------------------------------------------------------------------
# Gouvernance : mode d'exécution + journal d'audit
# ---------------------------------------------------------------------------

def _mode() -> str:
    if MODE_FICHIER.exists():
        try:
            m = json.loads(MODE_FICHIER.read_text(encoding="utf-8")).get("mode")
            if m in MODES:
                return m
        except Exception:
            pass
    return "autonome"


def _set_mode(m: str) -> None:
    if m not in MODES:
        raise HTTPException(400, f"Mode inconnu : {m}")
    MODE_FICHIER.write_text(
        json.dumps({"mode": m, "depuis": datetime.now().isoformat(timespec="seconds")},
                   ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _journaliser(evenement: str, detail: dict) -> str:
    """Ajoute une entrée au registre d'audit hash-chaîné (ISO 27001).
    Chaque entrée scelle la précédente : toute altération casse la chaîne."""
    prec = "0" * 64
    if REGISTRE.exists():
        lignes = REGISTRE.read_text(encoding="utf-8").strip().splitlines()
        if lignes:
            try:
                prec = json.loads(lignes[-1])["hash"]
            except Exception:
                pass
    entree = {
        "horodatage": datetime.now().isoformat(timespec="seconds"),
        "evenement": evenement,
        "detail": detail,
        "prec": prec,
    }
    sceau = json.dumps(entree, ensure_ascii=False, sort_keys=True)
    entree["hash"] = hashlib.sha256((prec + sceau).encode("utf-8")).hexdigest()
    with REGISTRE.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entree, ensure_ascii=False) + "\n")
    return entree["hash"]


def _decoder_ps(script: str) -> str:
    """Décode le wrapper Invoke-Expression(FromBase64String('…')) → script lisible.
    La transparence (voir ce qu'on approuve) est la base de la validation humaine."""
    m = re.search(r"FromBase64String\('([A-Za-z0-9+/=]+)'\)", script or "")
    if m:
        try:
            return base64.b64decode(m.group(1)).decode("utf-16-le")
        except Exception:
            return script
    return script


def _commande_lisible(d: dict) -> str:
    """Représentation humaine d'une commande (ce que l'admin exécuterait)."""
    action = d.get("action")
    p = d.get("params", {}) or {}
    if action == "shell":
        return _decoder_ps(p.get("script", "")).strip()
    if action == "download":
        return (f"# Téléchargement de fichier\n"
                f"Invoke-WebRequest -Uri '{p.get('url')}' -OutFile '{p.get('dest')}' -UseBasicParsing")
    if action == "screenshot":
        return "# Capture d'écran du poste (aucune commande à exécuter)"
    if action == "tail":
        return f"Get-Content '{p.get('path')}' -Tail {p.get('lignes', 40)}"
    if action == "exists":
        return f"Test-Path '{p.get('path')}'"
    if action == "sha256":
        return f"Get-FileHash '{p.get('path')}' -Algorithm SHA256"
    if action == "http":
        return f"Invoke-WebRequest -Uri '{p.get('url')}' -UseBasicParsing"
    if action == "installer":
        return f"Start-Process '{p.get('path')}' {('-ArgumentList ' + str(p.get('args'))) if p.get('args') else ''}"
    return json.dumps({"action": action, "params": p}, ensure_ascii=False, indent=2)


# ---------------------------------------------------------------------------
# API tickets
# ---------------------------------------------------------------------------

@app.post("/api/tickets")
async def creer_ticket(
    request: Request,
    message: str = Form(""),
    scenario: str = Form(""),
    fichiers: List[UploadFile] = File(default=[]),
):
    if not message.strip() and not fichiers:
        raise HTTPException(400, "Ticket vide : message ou fichier requis")

    lus = [(f.filename, await f.read()) for f in fichiers]
    machine = request.client.host if request.client else "inconnue"
    ticket_id, noms = _ecrire_ticket(message, scenario, machine, lus)
    return {"ok": True, "id": ticket_id, "fichiers": noms}


@app.get("/api/tickets")
async def lister_tickets():
    return {"tickets": _lister_tickets()}


@app.get("/api/tickets/{ticket_id}/fichiers/{nom}")
async def lire_fichier(ticket_id: str, nom: str):
    chemin = (INBOX / _nom_sur(ticket_id) / _nom_sur(nom)).resolve()
    if not str(chemin).startswith(str(INBOX.resolve())) or not chemin.exists():
        raise HTTPException(404, "Fichier introuvable")
    return FileResponse(chemin)


# ---------------------------------------------------------------------------
# API checklist & PV
# ---------------------------------------------------------------------------

@app.get("/api/checklist")
async def get_checklist():
    return {"version": VERSION_RECETTE, "scenarios": _charger_checklist()}


@app.post("/api/checklist/{scenario_id}")
async def maj_checklist(scenario_id: str, statut: str = Form(...), commentaire: str = Form("")):
    if statut not in ("ok", "ko", "en_attente"):
        raise HTTPException(400, "Statut invalide (ok | ko | en_attente)")
    scenarios = _charger_checklist()
    for s in scenarios:
        if s["id"] == scenario_id:
            s["statut"] = statut
            s["commentaire"] = commentaire
            s["horodatage"] = datetime.now().isoformat(timespec="seconds")
            break
    else:
        raise HTTPException(404, "Scénario inconnu")
    CHECKLIST_FICHIER.write_text(
        json.dumps(scenarios, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return {"ok": True}


@app.get("/api/pv", response_class=PlainTextResponse)
async def exporter_pv():
    scenarios = _charger_checklist()
    tickets = _lister_tickets()
    date = datetime.now()
    ok = sum(1 for s in scenarios if s["statut"] == "ok")
    ko = sum(1 for s in scenarios if s["statut"] == "ko")
    lignes = [
        f"# Procès-verbal de recette — {VERSION_RECETTE}",
        "",
        f"**Date :** {date:%d/%m/%Y %H:%M}  ",
        f"**Résultat :** {ok} OK / {ko} KO / {len(scenarios) - ok - ko} non testés",
        "",
        "## Checklist",
        "",
        "| Scénario | Statut | Commentaire |",
        "|---|---|---|",
    ]
    icones = {"ok": "✅ OK", "ko": "❌ KO", "en_attente": "⬜ non testé"}
    for s in scenarios:
        lignes.append(f"| {s['titre']} | {icones[s['statut']]} | {s.get('commentaire', '')} |")
    lignes += ["", f"## Tickets déposés ({len(tickets)})", ""]
    for t in tickets:
        extrait = (t["message"] or "").strip().replace("\n", " ")[:100]
        pj = f" — {len(t['fichiers'])} pièce(s) jointe(s)" if t["fichiers"] else ""
        lignes.append(f"- `{t['id']}` [{t['statut']}] {t['machine']} — {extrait}{pj}")
    pv = "\n".join(lignes) + "\n"
    (RACINE / f"PV-recette-{date:%Y%m%d-%H%M}.md").write_text(pv, encoding="utf-8")
    return pv


# ---------------------------------------------------------------------------
# API agent — file de commandes bidirectionnelle (recette automatisée)
# ---------------------------------------------------------------------------
# Flux : l'assistant (depuis Abux, en local) POSTe une commande → l'agent
# PowerShell du poste de test la récupère (jeton), l'exécute, et renvoie le
# résultat (texte + captures) qui devient un ticket visible sur le tableau.


class Commande(BaseModel):
    action: str
    params: dict = {}
    machine: str = ""      # poste cible (vide = n'importe quel agent)
    libelle: str = ""
    scenario: str = ""
    explication: str = ""  # ce que fait la commande + pourquoi (validation humaine)
    risque: str = "faible" # faible | moyen | eleve


@app.post("/api/agent/commande")
async def poster_commande(cmd: Commande, request: Request):
    """Dépose une commande pour l'agent. Réservé au serveur local (l'assistant)."""
    hote = request.client.host if request.client else ""
    if hote not in ("127.0.0.1", "::1", "localhost"):
        raise HTTPException(403, "Commande autorisée uniquement en local (Abux)")
    COMMANDES.mkdir(exist_ok=True)
    horod = datetime.now()
    cid = f"C{horod:%Y%m%d-%H%M%S}-{secrets.token_hex(2)}"
    data = {
        "id": cid,
        "horodatage": horod.isoformat(timespec="seconds"),
        "action": cmd.action,
        "params": cmd.params,
        "machine": cmd.machine,
        "libelle": cmd.libelle,
        "scenario": cmd.scenario,
        "explication": cmd.explication,
        "risque": cmd.risque if cmd.risque in ("faible", "moyen", "eleve") else "faible",
        "lisible": _commande_lisible({"action": cmd.action, "params": cmd.params}),
        "etat": "en_attente",
        "approuve_agent": False,
        "decision": None,
    }
    (COMMANDES / f"{cid}.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    _journaliser("commande_proposee", {
        "commande": cid, "libelle": cmd.libelle, "risque": data["risque"], "mode": _mode(),
    })
    return {"ok": True, "id": cid, "mode": _mode()}


@app.get("/api/agent/commandes")
async def recuperer_commandes(token: str = "", machine: str = ""):
    """L'agent récupère ses commandes à exécuter — selon le MODE de gouvernance.

    - autonome : toutes les commandes en attente.
    - hybride  : seulement celles approuvées par un humain.
    - pilote   : aucune (l'admin exécute lui-même et recolle la sortie)."""
    if token != _token():
        raise HTTPException(401, "Jeton invalide")
    COMMANDES.mkdir(exist_ok=True)
    mode = _mode()
    if mode == "pilote":
        return {"commandes": [], "mode": mode}
    a_faire = []
    for f in sorted(COMMANDES.glob("C*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        if d["etat"] != "en_attente":
            continue
        if mode == "hybride" and not d.get("approuve_agent"):
            continue  # attend l'approbation humaine
        if d["machine"] and machine and d["machine"] != machine:
            continue
        d["etat"] = "delivree"
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
        a_faire.append({
            "id": d["id"], "action": d["action"], "params": d["params"],
            "libelle": d["libelle"], "scenario": d["scenario"],
        })
    return {"commandes": a_faire, "mode": mode}


@app.post("/api/agent/resultat")
async def resultat_agent(request: Request):
    """L'agent renvoie le résultat d'une commande → devient un ticket.
    Parsing manuel en utf-8-sig : PowerShell 5.1 préfixe souvent le corps
    d'un BOM UTF-8 que le décodeur JSON strict refuserait (→ 400)."""
    brut = await request.body()
    payload = None
    # PowerShell 5.1 encode le corps en cp1252 (codepage Windows), parfois avec
    # un BOM. On tente UTF-8(+BOM) puis cp1252 puis latin-1 (qui ne lève jamais).
    for enc in ("utf-8-sig", "cp1252", "latin-1"):
        try:
            payload = json.loads(brut.decode(enc))
            break
        except Exception:
            continue
    if payload is None:
        with (RACINE / "debug-agent.log").open("a", encoding="utf-8") as dbg:
            dbg.write(f"\n--- {datetime.now().isoformat()} PARSE FAIL (toutes encodages)\n")
            dbg.write(f"content-type: {request.headers.get('content-type')}\n")
            dbg.write(f"len={len(brut)} premiers_octets={brut[:48]!r}\n")
        raise HTTPException(400, "Corps JSON illisible (encodage)")
    if payload.get("token") != _token():
        raise HTTPException(401, "Jeton invalide")
    cid = payload.get("commande_id", "")
    machine = payload.get("machine") or (request.client.host if request.client else "agent")
    libelle = payload.get("libelle", "")
    scenario = payload.get("scenario", "")
    message = payload.get("message", "")

    # Allègement : l'agent préfixe la sortie shell de "PS> <script>". Pour nos
    # commandes le script est un one-liner Invoke-Expression(...base64...) qui
    # pèse des milliers de tokens à chaque résultat. On retire cet écho ; seule
    # la VRAIE sortie est conservée.
    message = re.sub(
        r"^PS> .*?FromBase64String\([^\n]*\)\)\)\s*\n+", "", message, flags=re.DOTALL
    )

    fichiers = []
    for img in payload.get("captures", []):
        try:
            fichiers.append((img.get("nom", "capture.png"), base64.b64decode(img["b64"])))
        except Exception:
            pass

    entete = f"[AGENT {machine}] {libelle}".strip()
    corps = entete + (("\n\n" + message) if message else "")
    ticket_id, _ = _ecrire_ticket(
        corps, scenario, machine, fichiers,
        extra={"origine": "agent", "commande_id": cid},
    )

    cf = COMMANDES / f"{cid}.json"
    if cf.exists():
        d = json.loads(cf.read_text(encoding="utf-8"))
        d["etat"] = "terminee"
        d["ticket"] = ticket_id
        cf.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"ok": True, "ticket": ticket_id}


@app.post("/api/agent/capture")
async def capture_agent(request: Request, token: str = "", ticket: str = "", nom: str = "capture.png"):
    """Upload binaire brut d'une capture, rattachée à un ticket existant.
    Évite le base64-dans-JSON (limite MaxJsonLength de PowerShell 5.1)."""
    if token != _token():
        raise HTTPException(401, "Jeton invalide")
    dossier = (INBOX / _nom_sur(ticket)).resolve()
    if not str(dossier).startswith(str(INBOX.resolve())) or not dossier.exists():
        raise HTTPException(404, "Ticket introuvable")
    data = await request.body()
    if len(data) > 25 * 1024 * 1024:
        raise HTTPException(413, "Capture trop volumineuse (>25 Mo)")
    (dossier / _nom_sur(nom)).write_bytes(data)
    return {"ok": True, "octets": len(data)}


# ---------------------------------------------------------------------------
# Gouvernance : mode, validation humaine, registre d'audit
# ---------------------------------------------------------------------------

@app.get("/api/mode")
async def lire_mode():
    return {"mode": _mode(), "modes": list(MODES)}


@app.post("/api/mode")
async def changer_mode(request: Request, mode: str = Form(...)):
    u = _exiger(request, "mode")
    _set_mode(mode)
    _journaliser("changement_mode", {"mode": mode, "par": u["u"]})
    return {"ok": True, "mode": mode}


@app.get("/api/commandes/proposees")
async def commandes_proposees():
    """Liste des commandes proposées par l'assistant, en clair, pour la console."""
    COMMANDES.mkdir(exist_ok=True)
    cmds = []
    for f in sorted(COMMANDES.glob("C*.json"), reverse=True)[:40]:
        d = json.loads(f.read_text(encoding="utf-8"))
        cmds.append({
            "id": d["id"],
            "horodatage": d.get("horodatage", ""),
            "libelle": d.get("libelle", ""),
            "explication": d.get("explication", ""),
            "risque": d.get("risque", "faible"),
            "etat": d.get("etat", "en_attente"),
            "decision": d.get("decision"),
            "machine": d.get("machine") or "",
            "ticket": d.get("ticket"),
            "lisible": d.get("lisible") or _commande_lisible(d),
        })
    return {"mode": _mode(), "commandes": cmds}


def _charger_commande(cid: str) -> tuple:
    cf = COMMANDES / f"{_nom_sur(cid)}.json"
    if not cf.exists():
        raise HTTPException(404, "Commande introuvable")
    return cf, json.loads(cf.read_text(encoding="utf-8"))


@app.post("/api/commandes/{cid}/resultat-manuel")
async def resultat_manuel(cid: str, request: Request, sortie: str = Form("")):
    """L'admin a exécuté la commande lui-même et colle la sortie → devient un
    ticket que l'assistant lit (comme un résultat d'agent), traçé dans le registre."""
    u = _exiger(request, "executer")
    cf, d = _charger_commande(cid)
    entete = f"[HUMAIN {d.get('machine') or 'poste'}] {d.get('libelle', '')}".strip()
    corps = entete + (("\n\n" + sortie) if sortie.strip() else "\n\n(commande exécutée — aucune sortie collée)")
    ticket_id, _ = _ecrire_ticket(
        corps, d.get("scenario", ""), d.get("machine", ""),
        extra={"origine": "manuel", "commande_id": cid},
    )
    d["etat"] = "terminee"
    d["ticket"] = ticket_id
    d["decision"] = "execute_manuel"
    cf.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    _journaliser("execution_manuelle", {"commande": cid, "ticket": ticket_id, "par": u["u"]})
    return {"ok": True, "ticket": ticket_id}


@app.post("/api/commandes/{cid}/approuver")
async def approuver_commande(cid: str, request: Request):
    """Mode hybride : l'humain autorise l'agent à exécuter cette commande."""
    u = _exiger(request, "approuver")
    cf, d = _charger_commande(cid)
    d["approuve_agent"] = True
    d["decision"] = "approuve_agent"
    d["approuve_par"] = u["u"]
    cf.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    _journaliser("approbation", {"commande": cid, "libelle": d.get("libelle", ""), "par": u["u"]})
    return {"ok": True}


@app.post("/api/commandes/{cid}/refuser")
async def refuser_commande(cid: str, request: Request, motif: str = Form("")):
    """L'humain refuse la commande ; l'assistant en est informé par un ticket."""
    u = _exiger(request, "approuver")
    cf, d = _charger_commande(cid)
    d["etat"] = "refusee"
    d["decision"] = "refuse"
    d["motif"] = motif
    cf.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
    _journaliser("refus", {"commande": cid, "motif": motif, "par": u["u"]})
    _ecrire_ticket(
        f"[REFUS HUMAIN] Commande refusée : {d.get('libelle', '')}"
        + (f"\nMotif : {motif}" if motif else ""),
        d.get("scenario", ""), d.get("machine", ""),
        extra={"origine": "refus", "commande_id": cid},
    )
    return {"ok": True}


@app.get("/api/registre", response_class=PlainTextResponse)
async def exporter_registre(verif: bool = False):
    """Registre d'audit hash-chaîné. ?verif=1 vérifie l'intégrité de la chaîne."""
    if not REGISTRE.exists():
        return "Registre d'audit vide."
    lignes = REGISTRE.read_text(encoding="utf-8").strip().splitlines()
    if not verif:
        return "\n".join(lignes)
    prec = "0" * 64
    for i, ligne in enumerate(lignes, 1):
        e = json.loads(ligne)
        h = e.pop("hash", "")
        recompute = hashlib.sha256(
            (prec + json.dumps(e, ensure_ascii=False, sort_keys=True)).encode("utf-8")
        ).hexdigest()
        if e.get("prec") != prec or recompute != h:
            return f"⚠️ INTÉGRITÉ ROMPUE à l'entrée {i} ({e.get('horodatage')}). Le registre a été altéré."
        prec = h
    return f"✅ Registre intègre — {len(lignes)} entrées, chaîne de hachage vérifiée."


# ---------------------------------------------------------------------------
# Interface web
# ---------------------------------------------------------------------------

PAGE = """<!doctype html>
<html lang="fr"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PULSAR — Banc de Recette</title>
<style>
:root{--bleu:#0052cc;--fond:#f4f6fa;--ok:#1a7f37;--ko:#c4321e}
*{box-sizing:border-box}body{font-family:system-ui,Segoe UI,sans-serif;margin:0;background:var(--fond);color:#1b1f24}
header{background:var(--bleu);color:#fff;padding:14px 22px;display:flex;align-items:baseline;gap:14px}
header h1{font-size:18px;margin:0}header span{opacity:.8;font-size:13px}
main{max-width:1100px;margin:0 auto;padding:18px;display:grid;grid-template-columns:1fr 340px;gap:18px}
@media(max-width:900px){main{grid-template-columns:1fr}}
.carte{background:#fff;border:1px solid #d8dee6;border-radius:10px;padding:16px;margin-bottom:18px}
h2{font-size:15px;margin:0 0 10px}
textarea{width:100%;min-height:110px;border:1px solid #c4ccd6;border-radius:8px;padding:10px;font:13px/1.5 ui-monospace,monospace;resize:vertical}
#zone{border:2px dashed #9db3d0;border-radius:8px;padding:14px;text-align:center;color:#5a6b80;font-size:13px;margin:10px 0;background:#f8fafd}
#zone.actif{border-color:var(--bleu);background:#eaf1fb}
#apercus{display:flex;gap:8px;flex-wrap:wrap;margin:8px 0}
#apercus .pj{position:relative;border:1px solid #d8dee6;border-radius:6px;padding:4px;font-size:11px;background:#fff}
#apercus img{max-height:70px;display:block;border-radius:4px}
button{background:var(--bleu);color:#fff;border:0;border-radius:8px;padding:9px 18px;font-size:14px;cursor:pointer}
button:hover{filter:brightness(1.1)}button.sec{background:#e3e8ef;color:#1b1f24;font-size:12px;padding:5px 10px}
select,input[type=text]{border:1px solid #c4ccd6;border-radius:6px;padding:7px;font-size:13px}
.ticket{border-left:4px solid #c4ccd6;padding:10px 12px;margin-bottom:10px;background:#fff;border-radius:0 8px 8px 0;border-top:1px solid #e5e9f0;border-right:1px solid #e5e9f0;border-bottom:1px solid #e5e9f0}
.ticket.repondu{border-left-color:var(--ok)}
.ticket .meta{font-size:11px;color:#5a6b80;margin-bottom:6px}
.ticket pre{white-space:pre-wrap;font:12px/1.5 ui-monospace,monospace;background:#f6f8fa;padding:8px;border-radius:6px;max-height:180px;overflow:auto;margin:6px 0}
.ticket img{max-width:200px;max-height:130px;border:1px solid #d8dee6;border-radius:6px;margin:3px;cursor:pointer}
.reponse{background:#eefaf0;border:1px solid #b9e3c2;border-radius:8px;padding:10px;margin-top:8px;font-size:13px}
.reponse::before{content:"🤖 Réponse de l'assistant";display:block;font-weight:600;font-size:11px;color:var(--ok);margin-bottom:5px}
.badge{display:inline-block;padding:2px 9px;border-radius:99px;font-size:11px;font-weight:600}
.badge.nouveau{background:#fff3cd;color:#7a5b00}.badge.repondu{background:#d6f5dd;color:var(--ok)}
.scn{display:flex;align-items:center;gap:8px;padding:7px 0;border-bottom:1px solid #eef1f5;font-size:13px}
.scn .titre{flex:1}
.scn button{padding:3px 10px;font-size:12px;border-radius:6px}
.scn .ok{background:#d6f5dd;color:var(--ok)}.scn .ko{background:#fde2dd;color:var(--ko)}
.scn.est-ok .titre{color:var(--ok)}.scn.est-ko .titre{color:var(--ko)}
.scn .etat{width:26px;text-align:center}
#notif{position:fixed;bottom:18px;right:18px;background:#1b1f24;color:#fff;padding:10px 16px;border-radius:8px;font-size:13px;opacity:0;transition:.3s}
.modebar{display:flex;gap:6px;margin-left:auto;align-items:center}
.modebar .lbl{font-size:11px;opacity:.85;margin-right:2px}
.modebar button{background:rgba(255,255,255,.15);color:#fff;border:1px solid rgba(255,255,255,.35);border-radius:7px;padding:5px 11px;font-size:12px}
.modebar button.actif{background:#fff;color:var(--bleu);font-weight:700}
.modeinfo{font-size:12px;background:#eef4ff;border:1px solid #cfe0ff;border-radius:8px;padding:8px 11px;margin-bottom:12px;color:#243b53}
.cmd{border:1px solid #d8dee6;border-radius:9px;padding:11px 13px;margin-bottom:11px;background:#fff;border-left:4px solid #c4ccd6}
.cmd.en_attente{border-left-color:#f0a500}.cmd.delivree{border-left-color:var(--bleu)}.cmd.terminee{border-left-color:var(--ok)}.cmd.refusee{border-left-color:var(--ko);opacity:.65}
.cmd .tete{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;margin-bottom:3px}
.cmd .expl{font-size:12px;color:#44505f;margin:2px 0 8px}
.cmd pre{white-space:pre-wrap;font:12px/1.45 ui-monospace,monospace;background:#0d1117;color:#e6edf3;padding:10px 12px;border-radius:7px;max-height:240px;overflow:auto;margin:0}
.cmd .barre{display:flex;gap:7px;flex-wrap:wrap;margin-top:8px}
.cmd .barre button{padding:5px 11px;font-size:12px}
.cmd textarea{min-height:64px;margin-top:7px}
.rq{display:inline-block;padding:1px 8px;border-radius:99px;font-size:10px;font-weight:700;text-transform:uppercase}
.rq.faible{background:#d6f5dd;color:var(--ok)}.rq.moyen{background:#fff3cd;color:#7a5b00}.rq.eleve{background:#fde2dd;color:var(--ko)}
.copybtn{background:#e3e8ef;color:#1b1f24}
.cmd .et{font-size:11px;color:#5a6b80;margin-left:auto;font-weight:400}
</style></head><body>
<header><h1>⚡ PULSAR — Banc de Recette</h1><span>__VERSION__</span>
 <div class="modebar"><span class="lbl">Exécution :</span>
  <button data-mode="autonome" onclick="setMode('autonome')">🤖 Autonome</button>
  <button data-mode="hybride" onclick="setMode('hybride')">⚖️ Hybride</button>
  <button data-mode="pilote" onclick="setMode('pilote')">🛡️ Piloté</button>
 </div>
 <span class="userbox" style="margin-left:16px;font-size:12px;opacity:.95;white-space:nowrap">__USER__</span></header>
<main>
<section>
  <div class="carte" id="carte-cmd">
    <h2>Commandes proposées par l'assistant <span id="cmd-compteur" style="font-weight:400;color:#5a6b80"></span></h2>
    <div id="modeinfo" class="modeinfo"></div>
    <div id="commandes">Chargement…</div>
  </div>
  <div class="carte">
    <h2>Déposer un retour de test</h2>
    <div style="display:flex;gap:8px;margin-bottom:8px">
      <select id="scenario"><option value="">— Scénario concerné (optionnel) —</option></select>
    </div>
    <textarea id="message" placeholder="Décris ce que tu observes, colle tes logs ici…"></textarea>
    <div id="zone">📋 Colle une capture d'écran ici avec <b>Ctrl+V</b> (Impr. écran puis coller) — ou glisse-dépose des fichiers</div>
    <div id="apercus"></div>
    <button id="envoyer">Envoyer à l'assistant</button>
  </div>
  <div class="carte">
    <h2>Fil des tickets <span id="compteur" style="font-weight:400;color:#5a6b80"></span></h2>
    <div id="tickets">Chargement…</div>
  </div>
</section>
<aside>
  <div class="carte">
    <h2>Checklist de recette</h2>
    <div id="checklist"></div>
    <div style="margin-top:12px;text-align:right">
      <a href="/api/pv" target="_blank"><button class="sec">📄 Exporter le PV de recette</button></a>
    </div>
  </div>
  <div class="carte">
    <h2>🔒 Journal d'audit ISO 27001</h2>
    <p style="font-size:12px;color:#5a6b80;margin:0 0 10px">Toute commande, approbation et exécution est scellée en chaîne de hachage SHA-256. Traçabilité inviolable des actions d'administration distante.</p>
    <div style="display:flex;gap:7px;flex-wrap:wrap">
      <a href="/api/registre" target="_blank"><button class="sec">📑 Voir le registre</button></a>
      <a href="/api/registre?verif=1" target="_blank"><button class="sec">✅ Vérifier l'intégrité</button></a>
    </div>
  </div>
</aside>
</main>
<div id="notif"></div>
<script>
const _f=window.fetch;window.fetch=async(...a)=>{const r=await _f(...a);if(r.status===401){location.href='/login';}return r};
const $=s=>document.querySelector(s);let pieces=[];
function notif(t){const n=$('#notif');n.textContent=t;n.style.opacity=1;setTimeout(()=>n.style.opacity=0,2500)}
function ajouterPiece(fichier){pieces.push(fichier);const d=document.createElement('div');d.className='pj';
 if(fichier.type.startsWith('image/')){const i=document.createElement('img');i.src=URL.createObjectURL(fichier);d.appendChild(i)}
 else d.textContent='📄 '+fichier.name;$('#apercus').appendChild(d)}
document.addEventListener('paste',e=>{for(const it of e.clipboardData.items){if(it.kind==='file'){
 const f=it.getAsFile();const nom=f.name&&f.name!=='image.png'?f.name:'capture-'+Date.now()+'.png';
 ajouterPiece(new File([f],nom,{type:f.type}));notif('Capture ajoutée — clique Envoyer')}}
 const txt=e.clipboardData.getData('text');
 if(txt&&document.activeElement!==$('#message')){e.preventDefault();const m=$('#message');m.value+=(m.value?'\\n':'')+txt;m.focus();notif('Texte collé dans le message')}});
const z=$('#zone');
z.addEventListener('dragover',e=>{e.preventDefault();z.classList.add('actif')});
z.addEventListener('dragleave',()=>z.classList.remove('actif'));
z.addEventListener('drop',e=>{e.preventDefault();z.classList.remove('actif');[...e.dataTransfer.files].forEach(ajouterPiece)});
$('#envoyer').onclick=async()=>{const fd=new FormData();fd.append('message',$('#message').value);
 fd.append('scenario',$('#scenario').value);pieces.forEach(f=>fd.append('fichiers',f,f.name));
 const r=await fetch('/api/tickets',{method:'POST',body:fd});
 if(r.ok){$('#message').value='';pieces=[];$('#apercus').innerHTML='';notif('✅ Transmis à l\\'assistant');charger()}
 else notif('⚠️ '+(await r.json()).detail)};
function echap(t){const d=document.createElement('div');d.textContent=t;return d.innerHTML}
async function charger(){
 const {tickets}=await(await fetch('/api/tickets')).json();
 $('#compteur').textContent='('+tickets.length+')';
 $('#tickets').innerHTML=tickets.length?tickets.map(t=>`
  <div class="ticket ${t.statut==='répondu'?'repondu':''}">
   <div class="meta"><span class="badge ${t.statut==='répondu'?'repondu':'nouveau'}">${t.statut}</span>
    ${t.id} · ${t.horodatage.replace('T',' ')} · poste ${t.machine}${t.scenario?' · scénario : '+echap(t.scenario):''}</div>
   ${t.message?'<pre>'+echap(t.message)+'</pre>':''}
   ${t.fichiers.map(f=>/\\.(png|jpe?g|gif|webp)$/i.test(f)
     ?`<a href="/api/tickets/${t.id}/fichiers/${f}" target="_blank"><img src="/api/tickets/${t.id}/fichiers/${f}"></a>`
     :`<div>📄 <a href="/api/tickets/${t.id}/fichiers/${f}" target="_blank">${f}</a></div>`).join('')}
   ${t.reponse?'<div class="reponse">'+echap(t.reponse).replace(/\\n/g,'<br>')+'</div>':''}
  </div>`).join(''):'<i style="color:#5a6b80;font-size:13px">Aucun ticket — dépose ton premier retour de test ci-dessus.</i>';
 const {scenarios}=await(await fetch('/api/checklist')).json();
 const sel=$('#scenario');if(sel.options.length<=1)scenarios.forEach(s=>sel.add(new Option(s.titre,s.id)));
 $('#checklist').innerHTML=scenarios.map(s=>`
  <div class="scn ${s.statut==='ok'?'est-ok':s.statut==='ko'?'est-ko':''}">
   <span class="etat">${s.statut==='ok'?'✅':s.statut==='ko'?'❌':'⬜'}</span>
   <span class="titre">${s.titre}</span>
   <button class="ok" onclick="majScn('${s.id}','ok')">OK</button>
   <button class="ko" onclick="majScn('${s.id}','ko')">KO</button>
  </div>`).join('');
}
async function majScn(id,statut){const fd=new FormData();fd.append('statut',statut);
 let c='';if(statut==='ko'){c=prompt('Commentaire (que se passe-t-il ?)')||''}fd.append('commentaire',c);
 await fetch('/api/checklist/'+id,{method:'POST',body:fd});
 if(statut==='ko'&&c){const fd2=new FormData();fd2.append('message','[Checklist KO] '+c);fd2.append('scenario',id);
  await fetch('/api/tickets',{method:'POST',body:fd2})}
 charger()}
// ── Gouvernance : mode + commandes proposées ──
let MODE='autonome';
const INFO_MODE={
 autonome:"🤖 <b>Autonome</b> — l'agent exécute automatiquement les commandes proposées. Environnement de confiance / développement.",
 hybride:"⚖️ <b>Hybride</b> — chaque commande attend votre <b>approbation</b> avant d'être exécutée par l'agent. Automatisation sous contrôle.",
 pilote:"🛡️ <b>Piloté</b> — l'agent n'exécute <b>rien</b>. Vous copiez chaque commande, l'exécutez vous-même, et recollez la sortie. Validation 100% humaine (production / ISO 27001)."};
async function chargerMode(){const {mode}=await(await fetch('/api/mode')).json();MODE=mode;
 document.querySelectorAll('.modebar button').forEach(b=>b.classList.toggle('actif',b.dataset.mode===mode));
 $('#modeinfo').innerHTML=INFO_MODE[mode]||'';}
async function setMode(m){const fd=new FormData();fd.append('mode',m);await fetch('/api/mode',{method:'POST',body:fd});
 notif('Mode : '+m);await chargerMode();chargerCommandes();}
function copier(id){const el=document.getElementById('src-'+id);
 navigator.clipboard.writeText(el.textContent).then(()=>notif('📋 Commande copiée — exécute-la puis recolle la sortie'),
  ()=>{const r=document.createRange();r.selectNode(el);getSelection().removeAllRanges();getSelection().addRange(r);notif('Sélectionnée — Ctrl+C pour copier')});}
function toggleZone(id){const z=document.getElementById('zone-'+id);z.style.display=z.style.display==='block'?'none':'block';if(z.style.display==='block')document.getElementById('res-'+id).focus()}
async function approuver(id){await fetch('/api/commandes/'+id+'/approuver',{method:'POST'});notif('✅ Approuvée — l\\'agent va l\\'exécuter');chargerCommandes()}
async function refuser(id){const m=prompt('Motif du refus (optionnel) :')||'';const fd=new FormData();fd.append('motif',m);
 await fetch('/api/commandes/'+id+'/refuser',{method:'POST',body:fd});notif('✋ Commande refusée');chargerCommandes()}
async function envoyerResultat(id){const ta=document.getElementById('res-'+id);const fd=new FormData();fd.append('sortie',ta.value);
 const r=await fetch('/api/commandes/'+id+'/resultat-manuel',{method:'POST',body:fd});
 if(r.ok){notif('📨 Sortie transmise à l\\'assistant');chargerCommandes();charger()}else notif('⚠️ '+(await r.json()).detail)}
async function chargerCommandes(){
 const {commandes}=await(await fetch('/api/commandes/proposees')).json();
 const enc=commandes.filter(c=>c.etat==='en_attente'||c.etat==='delivree').length;
 $('#cmd-compteur').textContent=enc?'('+enc+' en cours)':'';
 $('#commandes').innerHTML=commandes.length?commandes.map(c=>{
  const att=c.etat==='en_attente';
  let actions='';
  if(att&&MODE==='pilote')actions=`<button class="copybtn" onclick="copier('${c.id}')">📋 Copier</button>
   <button onclick="toggleZone('${c.id}')">📥 Coller la sortie</button>
   <button class="sec" onclick="refuser('${c.id}')">✋ Refuser</button>`;
  else if(att&&MODE==='hybride')actions=`<button onclick="approuver('${c.id}')">✅ Exécuter via l'agent</button>
   <button class="copybtn" onclick="copier('${c.id}')">📋 Je l'exécute</button>
   <button onclick="toggleZone('${c.id}')">📥 Coller la sortie</button>
   <button class="sec" onclick="refuser('${c.id}')">✋ Refuser</button>`;
  else actions=`<button class="copybtn" onclick="copier('${c.id}')">📋 Copier</button>`;
  const etiq={en_attente:'⏳ en attente',delivree:'⏳ envoyée à l\\'agent',terminee:'✅ terminée',refusee:'✋ refusée'}[c.etat]||c.etat;
  return `<div class="cmd ${c.etat}">
   <div class="tete"><span class="rq ${c.risque}">${c.risque}</span>${echap(c.libelle||c.id)}<span class="et">${etiq}${c.ticket?' · '+c.ticket:''}</span></div>
   ${c.explication?'<div class="expl">'+echap(c.explication)+'</div>':''}
   <pre id="src-${c.id}">${echap(c.lisible)}</pre>
   <div class="barre">${actions}</div>
   <div id="zone-${c.id}" style="display:none">
    <textarea id="res-${c.id}" placeholder="Colle ici la sortie de la commande exécutée…"></textarea>
    <div class="barre"><button onclick="envoyerResultat('${c.id}')">📨 Transmettre la sortie à l'assistant</button></div>
   </div>
  </div>`}).join(''):'<i style="color:#5a6b80;font-size:13px">Aucune commande proposée pour l\\'instant.</i>';
}
chargerMode();charger();chargerCommandes();
setInterval(()=>{charger();chargerCommandes();chargerMode()},4000);
</script></body></html>"""


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    u = getattr(getattr(request, "state", None), "user", None) or {"u": "?", "r": "?"}
    badge = (f'👤 {u["u"]} · <b>{u["r"]}</b> · '
             '<a href="/logout" style="color:#fff;text-decoration:underline">Déconnexion</a>')
    return PAGE.replace("__VERSION__", VERSION_RECETTE).replace("__USER__", badge)


if __name__ == "__main__":
    import uvicorn

    INBOX.mkdir(exist_ok=True)
    REPONSES.mkdir(exist_ok=True)
    COMMANDES.mkdir(exist_ok=True)
    _charger_checklist()
    print(f"[recette] jeton agent : {_token()}")
    print("[recette] console : http://0.0.0.0:9333  ·  API agent active")
    uvicorn.run(app, host="0.0.0.0", port=9333, log_level="warning")
