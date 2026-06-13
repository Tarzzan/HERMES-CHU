# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
Générateur de livrable de recette — PULSAR (CHU de Guyane).
=============================================================
Produit un Procès-Verbal de Recette autonome (HTML+CSS+JS embarqués),
imprimable en PDF, à partir des données factuelles de `recette/` :
checklist, tickets, registre d'audit hash-chaîné, commandes.

Principe déontologique : la SYNTHÈSE est rédigée proprement (rapport
professionnel) ; les ANNEXES (registre, commandes) restent FACTUELLES et
intactes — la preuve n'est jamais retouchée (intégrité par hachage).

    python3 recette/generer_livrable.py   → recette/livrable-recette.html
"""
from __future__ import annotations

import base64
import hashlib
import html
import json
import subprocess
from datetime import datetime
from pathlib import Path

RACINE = Path(__file__).parent
INBOX = RACINE / "inbox"
REPONSES = RACINE / "reponses"
COMMANDES = RACINE / "commandes"
REGISTRE = RACINE / "registre-actions.jsonl"
CHECKLIST = RACINE / "checklist.json"

AUTEUR = "William MERI"
ORG = "DSIO — Centre Hospitalier de Cayenne / CHU de Guyane"
VERSION = "PULSAR-Setup-2.3.1"
SORTIE = RACINE / "livrable-recette.html"

E = lambda s: html.escape(str(s or ""))
_IMG_EXT = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")


def embed_capture(chemin: Path, largeur: int = 980, qualite: int = 72) -> str | None:
    """Redimensionne une capture en vignette JPEG et la renvoie en data-URI base64.
    Rend le livrable AUTONOME (images dans le HTML, imprimables en PDF)."""
    if chemin.suffix.lower() not in _IMG_EXT or not chemin.exists():
        return None
    try:
        out = subprocess.run(
            ["convert", str(chemin), "-auto-orient", "-resize", f"{largeur}x>",
             "-quality", str(qualite), "jpg:-"],
            capture_output=True, timeout=20,
        )
        if out.returncode != 0 or not out.stdout:
            return None
        b64 = base64.b64encode(out.stdout).decode("ascii")
        return f"data:image/jpeg;base64,{b64}"
    except Exception:
        return None


def charger_checklist():
    if not CHECKLIST.exists():
        return []
    return json.loads(CHECKLIST.read_text(encoding="utf-8"))


def charger_tickets():
    tickets = []
    if not INBOX.exists():
        return tickets
    for d in sorted(INBOX.iterdir()):
        mf = d / "meta.json"
        if not d.is_dir() or not mf.exists():
            continue
        m = json.loads(mf.read_text(encoding="utf-8"))
        msgf = d / "message.txt"
        m["message"] = msgf.read_text(encoding="utf-8") if msgf.exists() else ""
        m["captures"] = sorted(
            f.name for f in d.iterdir()
            if f.name not in ("meta.json", "message.txt")
        )
        rf = REPONSES / f"{d.name}.md"
        m["reponse"] = rf.read_text(encoding="utf-8") if rf.exists() else ""
        tickets.append(m)
    return tickets


def verifier_registre():
    """Recalcule la chaîne de hachage et renvoie (nb, intègre, événements)."""
    if not REGISTRE.exists():
        return 0, True, {}
    lignes = REGISTRE.read_text(encoding="utf-8").strip().splitlines()
    prec = "0" * 64
    intacte = True
    evts = {}
    for ligne in lignes:
        e = json.loads(ligne)
        evts[e.get("evenement", "?")] = evts.get(e.get("evenement", "?"), 0) + 1
        h = e.get("hash", "")
        sans = {k: v for k, v in e.items() if k != "hash"}
        recompute = hashlib.sha256(
            (prec + json.dumps(sans, ensure_ascii=False, sort_keys=True)).encode("utf-8")
        ).hexdigest()
        if e.get("prec") != prec or recompute != h:
            intacte = False
            break
        prec = h
    return len(lignes), intacte, evts


def nb_commandes():
    return len(list(COMMANDES.glob("C*.json"))) if COMMANDES.exists() else 0


def synthese(checklist, n_tickets, n_cmd, n_audit, intacte):
    """Synthèse exécutive — rédaction professionnelle (le rapport, pas la preuve)."""
    ok = sum(1 for s in checklist if s["statut"] == "ok")
    ko = sum(1 for s in checklist if s["statut"] == "ko")
    total = len(checklist) or 1
    verdict = "VALIDÉE SANS RÉSERVE" if ko == 0 and ok == total else (
        "VALIDÉE AVEC RÉSERVES" if ko else "EN COURS")
    return f"""
La campagne de recette du livrable <strong>{E(VERSION)}</strong> a été conduite à distance,
depuis le poste de développement vers le poste de test du réseau hospitalier, au moyen d'un
agent de supervision en liaison sortante sécurisée (modèle pull / beaconing). Chaque action
d'administration distante a été journalisée et scellée en chaîne de hachage SHA-256.</p>
<p>L'ensemble des <strong>{total} scénarios</strong> de la checklist de recette a été exécuté :
<strong>{ok} conformes</strong>{(", <strong>" + str(ko) + " non conformes</strong>") if ko else ""}.
La campagne a généré <strong>{n_tickets} tickets</strong> de retour et <strong>{n_cmd} commandes</strong>
d'administration tracées, dont <strong>{n_audit} actions</strong> scellées au registre d'audit
({'intégrité vérifiée' if intacte else '⚠ intégrité rompue'}).</p>
<p>Au vu de ces résultats, le livrable {E(VERSION)} est déclaré <strong>{verdict}</strong>"""


def page():
    checklist = charger_checklist()
    tickets = charger_tickets()
    n_audit, intacte, evts = verifier_registre()
    n_cmd = nb_commandes()
    maintenant = datetime.now()

    # --- checklist ---
    lignes_cl = ""
    for i, s in enumerate(checklist, 1):
        st = s["statut"]
        badge = {"ok": ("OK", "ok"), "ko": ("NON CONFORME", "ko")}.get(st, ("EN ATTENTE", "att"))
        com = f'<div class="com">{E(s.get("commentaire"))}</div>' if s.get("commentaire") else ""
        lignes_cl += (f'<tr><td class="num">{i}</td><td>{E(s["titre"])}{com}</td>'
                      f'<td><span class="badge {badge[1]}">{badge[0]}</span></td></tr>')

    # --- journal des tickets (factuel, compact) ---
    lignes_tk = ""
    for t in tickets:
        msg = (t.get("message") or "").strip()
        if len(msg) > 700:
            msg = msg[:700] + " […]"
        origine = "Agent" if msg.startswith("[AGENT") or msg.startswith("[HUMAIN") else "Retour testeur"
        # galerie : captures embarquées (vignettes base64 cliquables = livrable autonome)
        galerie = ""
        dossier = INBOX / t["id"]
        for nom in t.get("captures", []):
            uri = embed_capture(dossier / nom)
            if uri:
                galerie += f'<img class="cap" src="{uri}" alt="{E(nom)}" title="{E(nom)} — cliquer pour agrandir" onclick="zoom(this.src)">'
            else:
                galerie += f'<span class="pj-file">📎 {E(nom)}</span>'
        caps = (f' · <span class="pj">{len(t["captures"])} pièce(s) jointe(s)</span>'
                if t.get("captures") else "")
        corps = f'<pre>{E(msg)}</pre>' if msg else ('' if galerie else '<em class="muet">(capture seule)</em>')
        gal = f'<div class="gal">{galerie}</div>' if galerie else ''
        lignes_tk += (
            f'<div class="tk"><div class="tkh"><span class="tkid">{E(t["id"])}</span>'
            f'<span class="tkm">{E(t["horodatage"].replace("T", " "))} · poste {E(t["machine"])} · '
            f'<span class="org">{origine}</span>{caps}</span></div>{corps}{gal}</div>')

    # --- annexe registre ---
    lignes_ev = "".join(
        f'<tr><td>{E(k)}</td><td class="num">{v}</td></tr>'
        for k, v in sorted(evts.items(), key=lambda x: -x[1])
    ) or '<tr><td colspan="2" class="muet">Registre vide.</td></tr>'

    synth = synthese(checklist, len(tickets), n_cmd, n_audit, intacte)

    return f"""<!doctype html><html lang="fr"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Procès-Verbal de Recette — {E(VERSION)}</title>
<style>
:root{{--bleu:#0052cc;--bleu2:#1565C0;--encre:#1b2330;--gris:#5a6b80;--ok:#1a7f37;--ko:#c4321e;--fond:#f4f6fa;--bord:#d8dee6}}
*{{box-sizing:border-box}}
body{{font-family:'Segoe UI',system-ui,sans-serif;margin:0;background:var(--fond);color:var(--encre);line-height:1.55}}
.page{{max-width:900px;margin:24px auto;background:#fff;padding:0 0 40px;box-shadow:0 2px 18px rgba(0,0,0,.08);border-radius:10px;overflow:hidden}}
header.cover{{background:linear-gradient(135deg,var(--bleu),var(--bleu2));color:#fff;padding:34px 44px}}
header.cover .croix{{color:#EF5350;font-weight:700}}
header.cover h1{{margin:.2em 0 .1em;font-size:26px;letter-spacing:.5px}}
header.cover .sub{{opacity:.92;font-size:15px}}
header.cover .meta{{margin-top:18px;font-size:13px;opacity:.9;display:grid;grid-template-columns:1fr 1fr;gap:4px 24px;max-width:640px}}
.verdict{{display:flex;align-items:center;gap:14px;margin:0 44px;padding:16px 20px;border-radius:10px;background:#eaf7ee;border:1px solid #b9e3c2;transform:translateY(-22px)}}
.verdict.ko{{background:#fdecea;border-color:#f3c0ba}}
.verdict .v{{font-size:22px;font-weight:800;color:var(--ok)}}
.verdict.ko .v{{color:var(--ko)}}
.verdict .pct{{margin-left:auto;font-size:13px;color:var(--gris)}}
main{{padding:0 44px}}
h2{{font-size:17px;border-bottom:2px solid var(--bleu);padding-bottom:6px;margin:30px 0 14px;color:var(--bleu2)}}
h2 .n{{color:var(--bleu);font-weight:800;margin-right:8px}}
p{{margin:.5em 0}}
table{{width:100%;border-collapse:collapse;font-size:13.5px;margin:8px 0}}
th,td{{text-align:left;padding:9px 11px;border-bottom:1px solid var(--bord);vertical-align:top}}
th{{background:#f1f5fb;color:var(--gris);font-size:12px;text-transform:uppercase;letter-spacing:.04em}}
td.num{{text-align:right;font-variant-numeric:tabular-nums;color:var(--gris);width:42px}}
.badge{{display:inline-block;padding:2px 11px;border-radius:99px;font-size:11px;font-weight:700;white-space:nowrap}}
.badge.ok{{background:#d6f5dd;color:var(--ok)}}.badge.ko{{background:#fde2dd;color:var(--ko)}}.badge.att{{background:#fff3cd;color:#7a5b00}}
.com{{font-size:12px;color:var(--gris);margin-top:4px}}
.stats{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:6px 0}}
.stat{{background:#f8fafd;border:1px solid var(--bord);border-radius:10px;padding:12px 14px}}
.stat .big{{font-size:24px;font-weight:800;color:var(--bleu2);line-height:1}}
.stat .lab{{font-size:12px;color:var(--gris);margin-top:4px}}
.integ{{display:flex;align-items:center;gap:10px;background:#eef4ff;border:1px solid #cfe0ff;border-radius:10px;padding:12px 16px;font-size:13px;margin:10px 0}}
.integ.ko{{background:#fdecea;border-color:#f3c0ba}}
.tk{{border:1px solid var(--bord);border-left:3px solid var(--bleu);border-radius:0 8px 8px 0;margin:9px 0;padding:9px 12px;background:#fff}}
.tkh{{display:flex;flex-wrap:wrap;gap:6px 12px;align-items:baseline;margin-bottom:5px}}
.tkid{{font:600 12px ui-monospace,monospace;color:var(--bleu2)}}
.tkm{{font-size:11.5px;color:var(--gris)}}
.tkm .org{{font-weight:600;color:var(--encre)}}
.tkm .pj{{color:var(--bleu)}}
.tk pre{{white-space:pre-wrap;font:11.5px/1.45 ui-monospace,monospace;background:#f6f8fa;border-radius:6px;padding:8px 10px;margin:0;max-height:240px;overflow:auto}}
.gal{{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}}
.cap{{max-height:160px;max-width:260px;border:1px solid var(--bord);border-radius:6px;cursor:zoom-in;object-fit:cover;break-inside:avoid}}
.pj-file{{font-size:12px;color:var(--gris);background:#f1f5fb;border:1px solid var(--bord);border-radius:6px;padding:3px 8px}}
#lb{{position:fixed;inset:0;background:rgba(10,16,24,.92);display:none;align-items:center;justify-content:center;z-index:50;cursor:zoom-out}}
#lb img{{max-width:94%;max-height:94%;border-radius:6px;box-shadow:0 6px 40px rgba(0,0,0,.5)}}
.muet{{color:#90a0b3}}
.sign{{margin-top:34px;display:grid;grid-template-columns:1fr 1fr;gap:24px}}
.sign .box{{border:1px solid var(--bord);border-radius:8px;padding:14px 16px;font-size:13px}}
.sign .who{{font-weight:700}}.sign .role{{color:var(--gris);font-size:12px}}
.sign .line{{margin-top:34px;border-top:1px dashed #b6c2d2;padding-top:5px;color:var(--gris);font-size:11px}}
footer{{margin:30px 44px 0;padding-top:14px;border-top:1px solid var(--bord);font-size:11px;color:var(--gris);display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px}}
.toolbar{{position:sticky;top:0;background:#fff;border-bottom:1px solid var(--bord);padding:8px 44px;display:flex;gap:10px;z-index:5}}
.toolbar button{{background:var(--bleu);color:#fff;border:0;border-radius:7px;padding:7px 14px;font-size:13px;cursor:pointer}}
.toolbar button.sec{{background:#e3e8ef;color:var(--encre)}}
@media print{{
  body{{background:#fff}}.page{{box-shadow:none;margin:0;max-width:none;border-radius:0}}
  .toolbar{{display:none}}.tk pre{{max-height:none}}.tk,.stat,table{{break-inside:avoid}}
  header.cover{{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
}}
</style></head><body>
<div class="toolbar">
  <button onclick="window.print()">🖨️ Imprimer / Exporter en PDF</button>
  <button class="sec" onclick="document.querySelectorAll('.tk pre').forEach(p=>p.style.maxHeight=p.style.maxHeight?'':'none')">Déplier les journaux</button>
</div>
<div class="page">
<header class="cover">
  <div class="sub"><span class="croix">✚</span> {E(ORG)}</div>
  <h1>Procès-Verbal de Recette</h1>
  <div class="sub">Livrable testé : <strong>{E(VERSION)}</strong></div>
  <div class="meta">
    <div>Référence : PV-RECETTE-{maintenant:%Y%m%d}</div><div>Date d'édition : {maintenant:%d/%m/%Y %H:%M}</div>
    <div>Responsable recette : {E(AUTEUR)}</div><div>Périmètre : installateur, CLI, dashboard web, desktop</div>
  </div>
</header>
<div class="verdict {'ko' if any(s['statut']=='ko' for s in checklist) else ''}">
  <div class="v">{'✓ RECETTE VALIDÉE' if checklist and all(s['statut']=='ok' for s in checklist) else '◑ RECETTE EN COURS'}</div>
  <div class="pct">{sum(1 for s in checklist if s['statut']=='ok')}/{len(checklist) or 0} scénarios conformes</div>
</div>
<main>
  <h2><span class="n">1.</span>Synthèse exécutive</h2>
  <p>{synth}, sous réserve de la traçabilité ci-jointe.</p>

  <h2><span class="n">2.</span>Indicateurs de la campagne</h2>
  <div class="stats">
    <div class="stat"><div class="big">{len(tickets)}</div><div class="lab">Tickets de recette</div></div>
    <div class="stat"><div class="big">{n_cmd}</div><div class="lab">Commandes tracées</div></div>
    <div class="stat"><div class="big">{n_audit}</div><div class="lab">Actions auditées</div></div>
    <div class="stat"><div class="big">{sum(1 for s in checklist if s['statut']=='ok')}/{len(checklist) or 0}</div><div class="lab">Scénarios conformes</div></div>
  </div>

  <h2><span class="n">3.</span>Résultats de la checklist de recette</h2>
  <table><thead><tr><th>#</th><th>Scénario</th><th>Verdict</th></tr></thead><tbody>{lignes_cl or '<tr><td colspan=3 class=muet>Checklist vide.</td></tr>'}</tbody></table>

  <h2><span class="n">4.</span>Garantie d'intégrité</h2>
  <div class="integ {'ko' if not intacte else ''}">
    <span style="font-size:20px">{'🔒' if intacte else '⚠️'}</span>
    <div>Registre d'audit hash-chaîné (SHA-256) — <strong>{n_audit} entrées</strong>.
    {'Chaîne de hachage <strong>vérifiée</strong> : aucune action altérée a posteriori.' if intacte else 'INTÉGRITÉ ROMPUE : la chaîne a été modifiée.'}</div>
  </div>

  <h2><span class="n">5.</span>Journal des échanges <span style="font-weight:400;color:var(--gris);font-size:13px">(annexe factuelle — {len(tickets)} entrées)</span></h2>
  {lignes_tk or '<p class="muet">Aucun ticket.</p>'}

  <h2><span class="n">6.</span>Répartition des actions auditées</h2>
  <table><thead><tr><th>Type d'événement</th><th>Occurrences</th></tr></thead><tbody>{lignes_ev}</tbody></table>

  <div class="sign">
    <div class="box"><div class="who">{E(AUTEUR)}</div><div class="role">Responsable de la recette — {E(ORG)}</div><div class="line">Date et signature</div></div>
    <div class="box"><div class="who">Validation</div><div class="role">Visa hiérarchique / qualité</div><div class="line">Date et signature</div></div>
  </div>
</main>
<footer>
  <span>{E(ORG)} · Apache 2.0</span>
  <span>Édité le {maintenant:%d/%m/%Y à %H:%M} · les annexes 5 &amp; 6 sont des relevés factuels non retouchés</span>
</footer>
</div>
<div id="lb" onclick="this.style.display='none'"><img></div>
<script>
function zoom(src){{var lb=document.getElementById('lb');lb.querySelector('img').src=src;lb.style.display='flex';}}
document.addEventListener('keydown',function(e){{if(e.key==='Escape')document.getElementById('lb').style.display='none';}});
</script>
</body></html>"""


if __name__ == "__main__":
    SORTIE.write_text(page(), encoding="utf-8")
    print(f"Livrable généré : {SORTIE} ({SORTIE.stat().st_size // 1024} Ko)")
