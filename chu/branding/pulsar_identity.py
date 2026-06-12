#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Pipeline d'identité de marque
======================================
Applique l'identité PULSAR sur TOUTES les surfaces visibles du moteur
(dashboard web, app desktop Electron, CLI) en une passe, de façon :

  * CHIRURGICALE  — uniquement des chaînes de marque EXACTES et auditées,
                    jamais un remplacement aveugle de « hermes ».
  * IDEMPOTENTE   — réexécutable sans effet de bord (si déjà PULSAR, on saute).
  * NON-DESTRUCTIVE pour le fonctionnel — on ne touche JAMAIS :
        - les noms de modules / imports (hermes_constants, hermes_cli…),
        - la variable d'env HERMES_HOME,
        - la détection de fournisseur d'API (base_url_host_matches "nousresearch.com"),
        - les noms de fonctions (get_hermes_home…), les liens d'issues upstream,
        - les noms réels de modèles (« Nous Research Hermes 3 & 4 »).

Usage (depuis la racine du dépôt) :
    python3 chu/branding/pulsar_identity.py            # dry-run : liste les changements
    python3 chu/branding/pulsar_identity.py --apply    # applique
    python3 chu/branding/pulsar_identity.py --apply --report   # applique + signale ce qui reste

À relancer après chaque mise à jour upstream — le moteur reste vanilla et
updatable ; l'identité est ré-appliquée par-dessus.
"""

from __future__ import annotations

import argparse
import glob
import os
import shutil
import sys

# Racine du moteur (relative à la racine du dépôt PULSAR-CHU)
ENGINE = "upstream/pulsar-agent"

# ---------------------------------------------------------------------------
# Remplacements de marque — (motif_glob, ancienne_chaine, nouvelle_chaine, libellé)
# Chaque entrée vise une chaîne VISIBLE précise, vérifiée comme non-fonctionnelle.
# ---------------------------------------------------------------------------
REPLACEMENTS = [
    # --- Dashboard web ---
    # Les fichiers i18n sont 100 % de l'affichage : remplacer le nom de marque
    # « Hermes Agent » -> « PULSAR » y est sans risque fonctionnel et couvre
    # brand, tweet d'achievement, etc., dans toutes les langues.
    ("web/src/i18n/*.ts",        "Hermes Agent",                    "PULSAR",                                         "i18n web : nom de marque"),
    ("web/src/i18n/*.ts",        'brandShort: "HA"',                'brandShort: "CHU"',                              "i18n web : brandShort"),
    ("web/src/i18n/*.ts",        'org: "Nous Research"',            'org: "CHU de Guyane"',                           "i18n web : org"),
    # --- i18n desktop (écrans setup/onboarding, toutes langues) ---
    ("apps/desktop/src/i18n/*.ts", "Hermes Agent",                  "PULSAR",                                         "i18n desktop : nom de marque"),
    ("apps/desktop/src/lib/desktop-slash-commands.ts", "Show Hermes Agent version", "Show PULSAR version",           "slash /version desktop"),
    ("web/index.html",           "<title>Hermes Agent - Dashboard</title>", "<title>PULSAR - DSIO CHU de Guyane</title>", "titre HTML web"),
    ("web/src/components/SidebarFooter.tsx", 'href="https://nousresearch.com"', 'href="https://github.com/Tarzzan/PULSAR-CHU"', "lien footer web"),

    # --- App desktop (Electron) ---
    ("apps/desktop/src/components/chat/intro.tsx", "const WORDMARK = 'HERMES AGENT'", "const WORDMARK = 'PULSAR'", "wordmark desktop"),
    ("apps/desktop/index.html",  "<title>Hermes</title>",           "<title>PULSAR</title>",                          "titre fenêtre desktop"),
    ("apps/desktop/src/components/chat/intro-copy.jsonl", '"headline":"Hermes Agent is ready."', '"headline":"PULSAR is ready."', "accueil desktop"),
    ("apps/desktop/package.json", '"productName": "Hermes"',        '"productName": "PULSAR"',                        "productName Electron"),
    ("apps/desktop/package.json", '"description": "Native desktop shell for Hermes Agent."', '"description": "Shell desktop natif pour PULSAR — CHU de Guyane."', "description Electron"),
]

# ---------------------------------------------------------------------------
# Assets d'identité — (source relative au dépôt, destination relative au moteur)
# Câble les icônes PULSAR (favicon, icône de l'app desktop).
# ---------------------------------------------------------------------------
ASSETS = [
    ("installer/windows/assets/pulsar.ico", "apps/desktop/assets/icon.ico",  "icône app desktop"),
    ("installer/windows/assets/pulsar.ico", "web/public/favicon.ico",        "favicon web"),
]

# Détection visible résiduelle (rapport) : ces motifs sont du branding visible
# qui pourrait subsister. On EXCLUT les contextes fonctionnels.
SCAN_GLOBS = ["web/src/**/*.ts", "web/src/**/*.tsx", "apps/desktop/src/**/*.ts", "apps/desktop/src/**/*.tsx"]
SCAN_PATTERNS = ["Hermes Agent", "HERMES AGENT"]
SCAN_EXCLUDE = ("test", "//", "bot_name", "HERMES_", "import ", "from hermes", "nousresearch.com")


def _files(motif: str):
    return sorted(glob.glob(os.path.join(ENGINE, motif), recursive=True))


def appliquer(apply: bool) -> int:
    n = 0
    print("=== Remplacements de marque ===")
    for motif, old, new, label in REPLACEMENTS:
        for f in _files(motif):
            try:
                txt = open(f, encoding="utf-8").read()
            except Exception:
                continue
            if old in txt:
                count = txt.count(old)
                rel = os.path.relpath(f, ENGINE)
                print(f"  [{'APPLIQUÉ' if apply else 'À FAIRE'}] {label:28} {rel}  (×{count})")
                if apply:
                    open(f, "w", encoding="utf-8").write(txt.replace(old, new))
                n += count
    print("=== Assets d'identité ===")
    for src, dst, label in ASSETS:
        dstp = os.path.join(ENGINE, dst)
        if not os.path.exists(src):
            print(f"  [absent ] {label:28} source manquante : {src}")
            continue
        deja = os.path.exists(dstp) and _meme(src, dstp)
        if deja:
            continue
        print(f"  [{'COPIÉ   ' if apply else 'À COPIER'}] {label:28} -> {dst}")
        if apply:
            os.makedirs(os.path.dirname(dstp), exist_ok=True)
            shutil.copy2(src, dstp)
        n += 1
    return n


def _meme(a: str, b: str) -> bool:
    try:
        return open(a, "rb").read() == open(b, "rb").read()
    except Exception:
        return False


def rapport():
    print("=== Branding visible résiduel (à examiner) ===")
    vus = 0
    for g in SCAN_GLOBS:
        for f in _files(g):
            try:
                lignes = open(f, encoding="utf-8").read().splitlines()
            except Exception:
                continue
            for i, ligne in enumerate(lignes, 1):
                strip = ligne.lstrip()
                if strip.startswith(("*", "//", "#", "/*")):
                    continue  # commentaire : non visible
                if any(p in ligne for p in SCAN_PATTERNS) and not any(x in ligne for x in SCAN_EXCLUDE):
                    print(f"  {os.path.relpath(f, ENGINE)}:{i}  {ligne.strip()[:90]}")
                    vus += 1
    if not vus:
        print("  (aucun — identité visible complète sur les surfaces scannées)")


def main():
    ap = argparse.ArgumentParser(description="Pipeline d'identité PULSAR")
    ap.add_argument("--apply", action="store_true", help="applique (sinon dry-run)")
    ap.add_argument("--report", action="store_true", help="signale le branding visible résiduel")
    args = ap.parse_args()

    if not os.path.isdir(ENGINE):
        print(f"Erreur : exécuter depuis la racine du dépôt (dossier '{ENGINE}' introuvable).")
        sys.exit(1)

    n = appliquer(args.apply)
    print(f"\n{'Appliqué' if args.apply else 'Détecté (dry-run)'} : {n} changement(s).")
    if args.report or not args.apply:
        print()
        rapport()
    if not args.apply and n:
        print("\nRelancer avec --apply pour appliquer.")


if __name__ == "__main__":
    main()
