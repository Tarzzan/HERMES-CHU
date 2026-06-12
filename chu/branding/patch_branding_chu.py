#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
HERMES CHU — Patch de branding hospitalier
Concu par William MERI — CHU de Guyane
Modifie les fichiers hermes-agent pour afficher le branding CHU de Guyane
Usage : python patch_branding_chu.py [--hermes-root PATH]
"""
import os
import sys
import shutil
import argparse
from pathlib import Path

# ============================================================
# Configuration du branding CHU
# ============================================================
BRANDING = {
    "brand": "HERMES CHU",
    "brand_short": "CHU",
    "footer_org": "William MERI · CHU de Guyane",
    "footer_url": "https://github.com/Tarzzan/PULSAR-CHU",
    "page_title": "HERMES CHU — CHU de Guyane",
    "agent_name": "HERMES CHU",
    "welcome": "Bienvenue sur HERMES CHU — Système Agentique Hospitalier du CHU de Guyane.",
    "skin": "chu-guyane",
}

def find_hermes_root() -> Path | None:
    """Trouver le dossier racine de hermes-agent."""
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "hermes-agent",
        Path(os.environ.get("USERPROFILE", "")) / ".hermes" / "hermes-agent",
        Path(os.environ.get("HOME", "")) / ".hermes" / "hermes-agent",
    ]
    # Chercher via la commande hermes dans le PATH
    import shutil as sh
    hermes_exe = sh.which("hermes")
    if hermes_exe:
        p = Path(hermes_exe).parent
        for _ in range(5):
            if (p / "hermes_cli").exists():
                candidates.insert(0, p)
                break
            p = p.parent
    for c in candidates:
        if c.exists() and (c / "hermes_cli").exists():
            return c
    return None


def patch_file(path: Path, replacements: list[tuple[str, str]], label: str) -> bool:
    """Appliquer des remplacements dans un fichier."""
    if not path.exists():
        print(f"  [INFO] Non trouvé : {path}")
        return False
    content = path.read_text(encoding="utf-8")
    original = content
    for old, new in replacements:
        content = content.replace(old, new)
    if content != original:
        # Backup
        backup = path.with_suffix(path.suffix + ".bak.chu")
        if not backup.exists():
            shutil.copy2(path, backup)
        path.write_text(content, encoding="utf-8")
        print(f"  [OK] Modifié : {label}")
        return True
    else:
        print(f"  [SKIP] Déjà modifié ou pattern non trouvé : {label}")
        return False


def patch_i18n(hermes_root: Path) -> None:
    """Modifier les fichiers i18n pour le branding CHU."""
    print("\n[2/5] Modification des fichiers i18n...")
    for lang in ["fr", "en"]:
        f = hermes_root / "web" / "src" / "i18n" / f"{lang}.ts"
        patch_file(f, [
            ('brand: "Hermes Agent"', f'brand: "{BRANDING["brand"]}"'),
            ("brand: 'Hermes Agent'", f"brand: '{BRANDING['brand']}'"),
            ('brandShort: "HA"', f'brandShort: "{BRANDING["brand_short"]}"'),
            ("brandShort: 'HA'", f"brandShort: '{BRANDING['brand_short']}'"),
            ('org: "Nous Research"', f'org: "{BRANDING["footer_org"]}"'),
            ("org: 'Nous Research'", f"org: '{BRANDING['footer_org']}'"),
        ], f"i18n/{lang}.ts")


def patch_sidebar_footer(hermes_root: Path) -> None:
    """Modifier le footer de la sidebar."""
    print("\n[3/5] Modification du footer sidebar...")
    f = hermes_root / "web" / "src" / "components" / "SidebarFooter.tsx"
    patch_file(f, [
        ('href="https://nousresearch.com"', f'href="{BRANDING["footer_url"]}"'),
        ("href='https://nousresearch.com'", f"href='{BRANDING['footer_url']}'"),
    ], "SidebarFooter.tsx")


def patch_index_html(hermes_root: Path) -> None:
    """Modifier le titre de la page HTML."""
    print("\n[4/5] Modification du titre HTML...")
    # Chercher dans web_dist (build) et web/src (source)
    candidates = [
        hermes_root / "hermes_cli" / "web_dist" / "index.html",
        hermes_root / "web" / "index.html",
    ]
    for f in candidates:
        patch_file(f, [
            ("<title>Hermes Agent - Dashboard</title>", f"<title>{BRANDING['page_title']}</title>"),
            ("<title>Hermes Agent</title>", f"<title>{BRANDING['page_title']}</title>"),
        ], f"index.html ({f.parent.name})")


def patch_config_yaml(hermes_root: Path) -> None:
    """Activer le skin CHU dans config.yaml."""
    print("\n[5/5] Activation du skin CHU dans config.yaml...")
    config_candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "config.yaml",
        Path(os.environ.get("USERPROFILE", "")) / ".hermes" / "config.yaml",
        Path(os.environ.get("HOME", "")) / ".hermes" / "config.yaml",
        hermes_root / "config.yaml",
    ]
    for config_path in config_candidates:
        if config_path.exists():
            content = config_path.read_text(encoding="utf-8")
            if "skin: chu-guyane" in content:
                print(f"  [OK] Skin CHU déjà actif dans : {config_path}")
            elif "display:" in content:
                # Vérifier si skin: existe sous display:
                import re
                if re.search(r"display:.*?skin:", content, re.DOTALL):
                    content = re.sub(r"(display:.*?skin:\s*)[\w-]+", r"\1chu-guyane", content, flags=re.DOTALL)
                else:
                    content = content.replace("display:", "display:\n  skin: chu-guyane", 1)
                backup = config_path.with_suffix(".yaml.bak.chu")
                if not backup.exists():
                    shutil.copy2(config_path, backup)
                config_path.write_text(content, encoding="utf-8")
                print(f"  [OK] Skin CHU activé dans : {config_path}")
            else:
                content = content.rstrip() + "\n\n# Branding CHU de Guyane\ndisplay:\n  skin: chu-guyane\n"
                backup = config_path.with_suffix(".yaml.bak.chu")
                if not backup.exists():
                    shutil.copy2(config_path, backup)
                config_path.write_text(content, encoding="utf-8")
                print(f"  [OK] Section display ajoutée dans : {config_path}")
            return
    print("  [INFO] config.yaml non trouvé — skin activé via variable d'environnement")


def install_skin(hermes_root: Path, script_dir: Path) -> None:
    """Installer le skin CHU dans le dossier des skins hermes."""
    print("\n[1/5] Installation du skin CHU...")
    hermes_home = Path(os.environ.get("LOCALAPPDATA", "")) / "hermes"
    if not hermes_home.exists():
        hermes_home = Path(os.environ.get("HOME", "")) / ".hermes"
    skins_dir = hermes_home / "skins"
    skins_dir.mkdir(parents=True, exist_ok=True)
    skin_source = script_dir / "chu-guyane.yaml"
    if skin_source.exists():
        shutil.copy2(skin_source, skins_dir / "chu-guyane.yaml")
        print(f"  [OK] Skin installé : {skins_dir / 'chu-guyane.yaml'}")
    else:
        print(f"  [INFO] Fichier skin non trouvé : {skin_source}")
        print("  Téléchargement depuis GitHub...")
        try:
            import urllib.request
            url = "https://raw.githubusercontent.com/Tarzzan/PULSAR-CHU/main/chu/branding/chu-guyane.yaml"
            urllib.request.urlretrieve(url, skins_dir / "chu-guyane.yaml")
            print(f"  [OK] Skin téléchargé : {skins_dir / 'chu-guyane.yaml'}")
        except Exception as e:
            print(f"  [WARN] Téléchargement échoué : {e}")


def main():
    parser = argparse.ArgumentParser(description="HERMES CHU — Patch de branding")
    parser.add_argument("--hermes-root", help="Chemin vers le dossier hermes-agent")
    args = parser.parse_args()

    print()
    print("=" * 60)
    print("  HERMES CHU — Application du branding hospitalier")
    print("  CHU de Guyane | William MERI | @Tarzzan")
    print("=" * 60)

    # Trouver hermes-agent
    if args.hermes_root:
        hermes_root = Path(args.hermes_root)
    else:
        hermes_root = find_hermes_root()

    if not hermes_root:
        print("\n[ERREUR] Dossier hermes-agent introuvable.")
        print("Utilisez : python patch_branding_chu.py --hermes-root CHEMIN")
        sys.exit(1)

    print(f"\n[OK] Hermes trouvé : {hermes_root}")

    script_dir = Path(__file__).parent

    # Appliquer les patches
    install_skin(hermes_root, script_dir)
    patch_i18n(hermes_root)
    patch_sidebar_footer(hermes_root)
    patch_index_html(hermes_root)
    patch_config_yaml(hermes_root)

    print()
    print("=" * 60)
    print("  Branding CHU appliqué avec succès !")
    print("=" * 60)
    print()
    print("Pour voir les changements :")
    print("  1. Fermez hermes dashboard (Ctrl+C)")
    print("  2. Relancez : hermes dashboard")
    print()
    print("Conçu par William MERI — CHU de Guyane")
    print("https://github.com/Tarzzan/PULSAR-CHU")


if __name__ == "__main__":
    main()
