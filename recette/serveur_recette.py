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
import json
import re
import secrets
from datetime import datetime
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse, PlainTextResponse
from pydantic import BaseModel

RACINE = Path(__file__).parent
INBOX = RACINE / "inbox"
REPONSES = RACINE / "reponses"
CHECKLIST_FICHIER = RACINE / "checklist.json"
COMMANDES = RACINE / "commandes"
TOKEN_FICHIER = RACINE / "agent-token.txt"

VERSION_RECETTE = "PULSAR-Setup-2.3.1"

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
        "etat": "en_attente",
    }
    (COMMANDES / f"{cid}.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return {"ok": True, "id": cid}


@app.get("/api/agent/commandes")
async def recuperer_commandes(token: str = "", machine: str = ""):
    """L'agent récupère ses commandes en attente (et les marque délivrées)."""
    if token != _token():
        raise HTTPException(401, "Jeton invalide")
    COMMANDES.mkdir(exist_ok=True)
    a_faire = []
    for f in sorted(COMMANDES.glob("C*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        if d["etat"] != "en_attente":
            continue
        if d["machine"] and machine and d["machine"] != machine:
            continue
        d["etat"] = "delivree"
        f.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")
        a_faire.append({
            "id": d["id"], "action": d["action"], "params": d["params"],
            "libelle": d["libelle"], "scenario": d["scenario"],
        })
    return {"commandes": a_faire}


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
</style></head><body>
<header><h1>⚡ PULSAR — Banc de Recette</h1><span>__VERSION__ · les dépôts sont transmis à l'assistant en temps réel</span></header>
<main>
<section>
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
</aside>
</main>
<div id="notif"></div>
<script>
const $=s=>document.querySelector(s);let pieces=[];
function notif(t){const n=$('#notif');n.textContent=t;n.style.opacity=1;setTimeout(()=>n.style.opacity=0,2500)}
function ajouterPiece(fichier){pieces.push(fichier);const d=document.createElement('div');d.className='pj';
 if(fichier.type.startsWith('image/')){const i=document.createElement('img');i.src=URL.createObjectURL(fichier);d.appendChild(i)}
 else d.textContent='📄 '+fichier.name;$('#apercus').appendChild(d)}
document.addEventListener('paste',e=>{for(const it of e.clipboardData.items){if(it.kind==='file'){
 const f=it.getAsFile();const nom=f.name&&f.name!=='image.png'?f.name:'capture-'+Date.now()+'.png';
 ajouterPiece(new File([f],nom,{type:f.type}));notif('Capture ajoutée — clique Envoyer')}}});
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
charger();setInterval(charger,4000);
</script></body></html>"""


@app.get("/", response_class=HTMLResponse)
async def index():
    return PAGE.replace("__VERSION__", VERSION_RECETTE)


if __name__ == "__main__":
    import uvicorn

    INBOX.mkdir(exist_ok=True)
    REPONSES.mkdir(exist_ok=True)
    COMMANDES.mkdir(exist_ok=True)
    _charger_checklist()
    print(f"[recette] jeton agent : {_token()}")
    print("[recette] console : http://0.0.0.0:9333  ·  API agent active")
    uvicorn.run(app, host="0.0.0.0", port=9333, log_level="warning")
