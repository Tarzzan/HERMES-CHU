#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Pipeline d'auteur & licence (source unique)
====================================================
Établit la paternité William MERI / licence Apache 2.0 de façon COHÉRENTE et
VÉRIFIABLE sur toutes les surfaces, à partir d'UNE seule source de vérité
(ci-dessous). Ré-exécutable après chaque mise à jour upstream.

Ce qu'il applique :
  * en-têtes SPDX sur les fichiers que TU as écrits (chu/, installeurs, scripts) ;
  * champs author/license dans les manifests (package.json desktop) ;
  * et fournit le texte « credits » (auteur · licence · version) pour la CLI
    (`pulsar credits` / À propos) et la bannière.

Il NE touche JAMAIS le moteur embarqué upstream/pulsar-agent/ (MIT © Nous
Research) — sa licence et ses en-têtes sont préservés (cf. NOTICE).

    python3 chu/branding/pulsar_authorship.py            # dry-run (liste)
    python3 chu/branding/pulsar_authorship.py --apply    # applique
    python3 chu/branding/pulsar_authorship.py --credits  # affiche les crédits
"""
from __future__ import annotations
import argparse
import glob
import json
import os
import re
import sys

# ───────────────────────── SOURCE UNIQUE DE VÉRITÉ ─────────────────────────
AUTHOR = "William MERI"
ORG = "DSIO, CHU de Guyane"
EMAIL = "william.meri@gmail.com"
LICENSE_ID = "Apache-2.0"
YEAR = "2026"
VERSION = "2.3.1"
REPO = "https://github.com/Tarzzan/PULSAR-CHU"
UPSTREAM = ("hermes-agent", "Nous Research", "MIT", "upstream/pulsar-agent")
# ───────────────────────────────────────────────────────────────────────────

SPDX_LICENSE = f"SPDX-License-Identifier: {LICENSE_ID}"
SPDX_COPYR = f"SPDX-FileCopyrightText: {YEAR} {AUTHOR} — {ORG}"

# Fichiers que TU as écrits (jamais le moteur upstream/).
SOURCE_GLOBS = [
    "chu/**/*.py", "chu/**/*.ps1", "chu/**/*.sh", "chu/**/*.js",
    "installer/windows/*.ps1", "recette/*.py",
]
COMMENT = {".py": "#", ".sh": "#", ".ps1": "#", ".js": "//"}


def _spdx_block(prefix: str) -> str:
    return f"{prefix} {SPDX_LICENSE}\n{prefix} {SPDX_COPYR}\n"


def _insert_spdx(path: str, apply: bool) -> bool:
    try:
        txt = open(path, encoding="utf-8").read()
    except Exception:
        return False
    if "SPDX-License-Identifier" in txt:
        return False  # idempotent
    prefix = COMMENT.get(os.path.splitext(path)[1], "#")
    block = _spdx_block(prefix)
    lines = txt.splitlines(keepends=True)
    # insérer après un éventuel shebang
    pos = 1 if lines and lines[0].startswith("#!") else 0
    new = "".join(lines[:pos]) + block + "".join(lines[pos:])
    if apply:
        open(path, "w", encoding="utf-8").write(new)
    return True


def apply_spdx(apply: bool) -> int:
    n = 0
    print("=== En-têtes SPDX (tes fichiers) ===")
    seen = set()
    for g in SOURCE_GLOBS:
        for f in glob.glob(g, recursive=True):
            if "__pycache__" in f or f in seen:
                continue
            seen.add(f)
            if _insert_spdx(f, apply):
                print(f"  [{'AJOUTÉ' if apply else 'À FAIRE'}] {f}")
                n += 1
    return n


def sync_manifest(apply: bool) -> int:
    """Champs author/license du package.json desktop (sans tout reformater)."""
    p = "upstream/pulsar-agent/apps/desktop/package.json"
    if not os.path.exists(p):
        return 0
    txt = open(p, encoding="utf-8").read()
    changed = 0
    print("=== Métadonnées manifest (package.json desktop) ===")
    # license
    if '"license"' not in txt:
        txt = re.sub(r'("description":\s*"[^"]*",)',
                     r'\1\n  "license": "' + LICENSE_ID + '",', txt, count=1)
        print(f"  [{'AJOUTÉ' if apply else 'À FAIRE'}] license = {LICENSE_ID}")
        changed += 1
    # author
    if '"author"' not in txt:
        txt = re.sub(r'("description":\s*"[^"]*",)',
                     r'\1\n  "author": "' + f"{AUTHOR} <{EMAIL}>" + '",', txt, count=1)
        print(f"  [{'AJOUTÉ' if apply else 'À FAIRE'}] author = {AUTHOR}")
        changed += 1
    if changed and apply:
        json.loads(txt)  # garde-fou : JSON toujours valide
        open(p, "w", encoding="utf-8").write(txt)
    if not changed:
        print("  (déjà présent)")
    return changed


def credits() -> str:
    return (
        f"PULSAR {VERSION}\n"
        f"  Auteur   : {AUTHOR} — {ORG} <{EMAIL}>\n"
        f"  Licence  : {LICENSE_ID} (libre de droit) — voir LICENSE\n"
        f"  Dépôt    : {REPO}\n"
        f"  Moteur   : {UPSTREAM[0]} © {UPSTREAM[1]} ({UPSTREAM[2]}, {UPSTREAM[3]}) — voir NOTICE\n"
    )


def main():
    ap = argparse.ArgumentParser(description="Pipeline d'auteur & licence PULSAR")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--credits", action="store_true")
    args = ap.parse_args()
    if args.credits:
        print(credits())
        return
    if not os.path.isdir("chu"):
        print("Exécuter depuis la racine du dépôt."); sys.exit(1)
    n = apply_spdx(args.apply) + sync_manifest(args.apply)
    print(f"\n{'Appliqué' if args.apply else 'Détecté'} : {n} changement(s).")
    print("\nFichiers légaux attendus à la racine : LICENSE, NOTICE, CITATION.cff")
    for f in ("LICENSE", "NOTICE", "CITATION.cff"):
        print(f"  [{'OK' if os.path.exists(f) else 'MANQUANT'}] {f}")
    if not args.apply and n:
        print("\nRelancer avec --apply pour appliquer.")


if __name__ == "__main__":
    main()
