#!/usr/bin/env python3
# ============================================================
#  PULSAR -- Patch Sources TypeScript
#  Plateforme Unifiee de Liaison, de Surveillance et
#  d'Assistance en temps Reel
#  DSIO -- CHU de Guyane | William MERI
#
#  Usage :
#    python patch_pulsar.py
#    python patch_pulsar.py --rebuild
#    python patch_pulsar.py --find-only
# ============================================================

import os
import sys
import shutil
import subprocess
import argparse
from pathlib import Path

# ── Couleurs terminal ─────────────────────────────────────────
def ok(msg):   print(f"  [OK]   {msg}")
def info(msg): print(f"  [INFO] {msg}")
def warn(msg): print(f"  [WARN] {msg}")
def err(msg):  print(f"  [ERR]  {msg}")
def step(n, t): print(f"\n  [{n}] {t}")

print()
print("  ============================================================")
print("  PULSAR -- Patch Sources TypeScript")
print("  DSIO -- CHU de Guyane | William MERI")
print("  ============================================================")
print()

parser = argparse.ArgumentParser()
parser.add_argument("--rebuild", action="store_true", help="Lancer npm run build apres les patches")
parser.add_argument("--find-only", action="store_true", help="Trouver les sources sans patcher")
args = parser.parse_args()

# ── Trouver le dossier hermes-agent ──────────────────────────
def find_hermes_agent():
    candidates = [
        Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "hermes-agent",
        Path(os.environ.get("USERPROFILE", "")) / ".hermes" / "hermes-agent",
        Path(os.environ.get("APPDATA", "")) / "hermes" / "hermes-agent",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "hermes" / "hermes-agent",
    ]

    # Chercher via le module Python hermes_cli
    try:
        import hermes_cli
        pkg_dir = Path(hermes_cli.__file__).parent
        # Remonter jusqu'au dossier hermes-agent
        for parent in [pkg_dir, pkg_dir.parent, pkg_dir.parent.parent]:
            if (parent / "web" / "src").exists():
                candidates.insert(0, parent)
    except ImportError:
        pass

    # Chercher via l'executable hermes dans le PATH
    hermes_exe = shutil.which("hermes")
    if hermes_exe:
        # hermes.exe est dans venv/Scripts/ -> remonter 3 niveaux
        p = Path(hermes_exe)
        for _ in range(4):
            p = p.parent
            if (p / "web" / "src").exists():
                candidates.insert(0, p)
                break

    for c in candidates:
        if c.exists() and (c / "web" / "src").exists():
            return c

    return None

step("1/8", "Recherche des sources hermes-agent...")
hermes_dir = find_hermes_agent()

if not hermes_dir:
    err("Sources hermes-agent introuvables.")
    print()
    print("  Definissez manuellement le chemin :")
    print("    set HERMES_AGENT_DIR=C:\\chemin\\vers\\hermes-agent")
    print("    python patch_pulsar.py")
    print()
    # Essayer via variable d'environnement
    env_dir = os.environ.get("HERMES_AGENT_DIR")
    if env_dir and Path(env_dir).exists():
        hermes_dir = Path(env_dir)
        ok(f"Source trouvee via HERMES_AGENT_DIR : {hermes_dir}")
    else:
        sys.exit(1)

ok(f"hermes-agent : {hermes_dir}")

web_src = hermes_dir / "web" / "src"
web_dir = hermes_dir / "web"

if args.find_only:
    info(f"web/src : {web_src}")
    info(f"web/    : {web_dir}")
    sys.exit(0)

# ── Sauvegarde ───────────────────────────────────────────────
step("2/8", "Sauvegarde des fichiers originaux...")
backup_dir = Path(os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))) / "hermes" / "pulsar-backup"
backup_dir.mkdir(parents=True, exist_ok=True)

files_to_backup = [
    web_dir / "index.html",
    web_src / "index.css",
    web_src / "themes" / "presets.ts",
    web_src / "i18n" / "fr.ts",
    web_src / "i18n" / "en.ts",
    web_src / "components" / "SidebarFooter.tsx",
]

for f in files_to_backup:
    if f.exists():
        dst = backup_dir / f.name
        shutil.copy2(f, dst)
        ok(f"Sauvegarde : {f.name}")

# ── Fonction de patch ─────────────────────────────────────────
def patch_file(path, replacements, label=None):
    p = Path(path)
    if not p.exists():
        warn(f"{p.name} : fichier introuvable ({p})")
        return False
    try:
        content = p.read_text(encoding="utf-8")
        changed = 0
        for old, new in replacements:
            if old in content:
                content = content.replace(old, new)
                changed += 1
        p.write_text(content, encoding="utf-8")
        if changed > 0:
            ok(f"{label or p.name} : {changed} remplacement(s)")
        else:
            warn(f"{label or p.name} : aucun remplacement (deja patche ou valeurs differentes)")
        return True
    except Exception as e:
        warn(f"{label or p.name} : {e}")
        return False

# ── Patch index.html ─────────────────────────────────────────
step("3/8", "Patch index.html (titre onglet navigateur)...")
patch_file(
    web_dir / "index.html",
    [
        ("<title>Hermes Agent - Dashboard</title>",
         "<title>PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane</title>"),
        ("<title>Hermes Agent</title>",
         "<title>PULSAR -- Systeme Agentique Medical | DSIO CHU de Guyane</title>"),
    ],
    "index.html"
)

# ── Patch i18n/fr.ts ─────────────────────────────────────────
step("4/8", "Patch i18n/fr.ts (branding francais)...")
patch_file(
    web_src / "i18n" / "fr.ts",
    [
        ('brand: "Hermes Agent"',      'brand: "PULSAR"'),
        ("brand: 'Hermes Agent'",      "brand: 'PULSAR'"),
        ('brandShort: "HA"',           'brandShort: "PSR"'),
        ("brandShort: 'HA'",           "brandShort: 'PSR'"),
        ('org: "Nous Research"',       'org: "DSIO CHU de Guyane"'),
        ("org: 'Nous Research'",       "org: 'DSIO CHU de Guyane'"),
        ('"Hermes Agent"',             '"PULSAR"'),
        ('updateHermes: "Mise a jour Hermes"',   'updateHermes: "Mise a jour PULSAR"'),
        ('updatingHermes: "Mise a jour de Hermes"', 'updatingHermes: "Mise a jour de PULSAR"'),
        ("Mise \u00e0 jour Herm\u00e8s",  "Mise a jour PULSAR"),
    ],
    "i18n/fr.ts"
)

# ── Patch i18n/en.ts ─────────────────────────────────────────
step("5/8", "Patch i18n/en.ts (branding anglais)...")
patch_file(
    web_src / "i18n" / "en.ts",
    [
        ('brand: "Hermes Agent"',      'brand: "PULSAR"'),
        ("brand: 'Hermes Agent'",      "brand: 'PULSAR'"),
        ('brandShort: "HA"',           'brandShort: "PSR"'),
        ("brandShort: 'HA'",           "brandShort: 'PSR'"),
        ('org: "Nous Research"',       'org: "DSIO CHU de Guyane"'),
        ("org: 'Nous Research'",       "org: 'DSIO CHU de Guyane'"),
        ('"Hermes Agent"',             '"PULSAR"'),
        ('Update Hermes',              'Update PULSAR'),
        ('Updating Hermes',            'Updating PULSAR'),
    ],
    "i18n/en.ts"
)

# ── Patch SidebarFooter.tsx ───────────────────────────────────
step("6/8", "Patch SidebarFooter.tsx (lien footer)...")
patch_file(
    web_src / "components" / "SidebarFooter.tsx",
    [
        ('href="https://nousresearch.com"',
         'href="https://github.com/Tarzzan/PULSAR-CHU"'),
        ("href='https://nousresearch.com'",
         "href='https://github.com/Tarzzan/PULSAR-CHU'"),
    ],
    "SidebarFooter.tsx"
)

# ── Patch themes/presets.ts ───────────────────────────────────
step("7/8", "Patch themes/presets.ts (palette PULSAR)...")
patch_file(
    web_src / "themes" / "presets.ts",
    [
        # Nom et description du theme default
        ('label: "Hermes Teal"',
         'label: "PULSAR"'),
        ("label: 'Hermes Teal'",
         "label: 'PULSAR'"),
        ('description: "Classic dark teal \u2014 the canonical Hermes look"',
         'description: "PULSAR \u2014 Systeme Agentique Medical | DSIO CHU de Guyane"'),
        ("description: 'Classic dark teal \u2014 the canonical Hermes look'",
         "description: 'PULSAR \u2014 Systeme Agentique Medical | DSIO CHU de Guyane'"),
        # Palette couleurs : or/teal NousResearch -> bleu nuit medical + cyan
        ('background: { hex: "#041c1c", alpha: 1 }',
         'background: { hex: "#020d1a", alpha: 1 }'),
        ('midground: { hex: "#ffe6cb", alpha: 1 }',
         'midground: { hex: "#00d4ff", alpha: 1 }'),
        ('warmGlow: "rgba(255, 189, 56, 0.35)"',
         'warmGlow: "rgba(0, 180, 216, 0.25)"'),
        # Large theme aussi
        ('label: "Hermes Teal (Large)"',
         'label: "PULSAR (Large)"'),
    ],
    "themes/presets.ts"
)

# ── Patch index.css ───────────────────────────────────────────
patch_file(
    web_src / "index.css",
    [
        ('--midground: color-mix(in srgb, #ffe6cb 100%, transparent);',
         '--midground: color-mix(in srgb, #00d4ff 100%, transparent);'),
        ('--midground-base: #ffe6cb;',
         '--midground-base: #00d4ff;'),
        ('--background: color-mix(in srgb, #041c1c 100%, transparent);',
         '--background: color-mix(in srgb, #020d1a 100%, transparent);'),
        ('--background-base: #041c1c;',
         '--background-base: #020d1a;'),
        ('--warm-glow: rgba(255, 189, 56, 0.35);',
         '--warm-glow: rgba(0, 180, 216, 0.25);'),
        ('--series-input-token: #ffe6cb;',
         '--series-input-token: #00d4ff;'),
    ],
    "index.css"
)

# ── Patch banner.py (Python CLI) ──────────────────────────────
try:
    import hermes_cli
    banner_py = Path(hermes_cli.__file__).parent / "banner.py"
    if banner_py.exists():
        patch_file(
            banner_py,
            [
                ("Nous Research",     "DSIO CHU de Guyane"),
                ("NousResearch",      "DSIO CHU de Guyane"),
                ("Hermes Agent",      "PULSAR"),
                ("hermes-agent",      "pulsar"),
            ],
            "banner.py"
        )
    skin_py = Path(hermes_cli.__file__).parent / "skin_engine.py"
    if skin_py.exists():
        patch_file(
            skin_py,
            [
                ('"agent_name": "Hermes Agent"',  '"agent_name": "PULSAR"'),
                ("'agent_name': 'Hermes Agent'",  "'agent_name': 'PULSAR'"),
                ('"Welcome to Hermes Agent!',      '"Bienvenue sur PULSAR -- DSIO CHU de Guyane!'),
                (" Hermes ",                       " PULSAR "),
            ],
            "skin_engine.py"
        )
    # Patch du skin hermes-teal installe (source du "AGENT HERMES" et "Nous Research")
    skins_dir = Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "skins"
    if not skins_dir.exists():
        skins_dir = Path(hermes_cli.__file__).parent.parent / "skins"
    for skin_file in list(skins_dir.glob("*.yaml")) + list(skins_dir.glob("*.yml")):
        patch_file(
            skin_file,
            [
                ("Nous Research",                "DSIO CHU de Guyane"),
                ("NousResearch",                 "DSIO CHU de Guyane"),
                ("Messenger of the Digital Gods", "Systeme Agentique Medical -- CHU de Guyane"),
                ("Hermes Agent",                 "PULSAR"),
                ("hermes-agent",                 "pulsar"),
                ("HERMES-AGENT",                 "PULSAR"),
                ("AGENT HERMES",                 "PULSAR"),
                ("Agent Hermes",                 "PULSAR"),
            ],
            f"skin/{skin_file.name}"
        )
except ImportError:
    warn("hermes_cli non trouve dans le PATH Python -- patches CLI ignores")

# ── Patch skins dans LOCALAPPDATA directement ─────────────────
step("7b/8", "Patch skins installes (AGENT HERMES, Nous Research)...")
for skins_root in [
    Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "skins",
    Path(os.environ.get("APPDATA", "")) / "hermes" / "skins",
    Path(os.environ.get("USERPROFILE", "")) / ".hermes" / "skins",
]:
    if skins_root.exists():
        for skin_file in list(skins_root.glob("*.yaml")) + list(skins_root.glob("*.yml")):
            patch_file(
                skin_file,
                [
                    ("Nous Research",                "DSIO CHU de Guyane"),
                    ("NousResearch",                 "DSIO CHU de Guyane"),
                    ("Messenger of the Digital Gods", "Systeme Agentique Medical -- CHU de Guyane"),
                    ("Hermes Agent",                 "PULSAR"),
                    ("HERMES-AGENT",                 "PULSAR"),
                    ("AGENT HERMES",                 "PULSAR"),
                    ("hermes-agent",                 "pulsar"),
                ],
                f"skin/{skin_file.name}"
            )
        ok(f"Skins patches dans : {skins_root}")

# ── Rebuild npm ───────────────────────────────────────────────
print()
print("  ============================================================")
print("  Patches appliques.")
print("  ============================================================")

# Trouver npm sur Windows (npm.cmd) ou Linux/Mac (npm)
def find_npm():
    for candidate in ["npm.cmd", "npm"]:
        found = shutil.which(candidate)
        if found:
            return found
    # Chercher dans les chemins Node.js courants sur Windows
    node_paths = [
        Path(os.environ.get("APPDATA", "")) / "npm" / "npm.cmd",
        Path(os.environ.get("PROGRAMFILES", "")) / "nodejs" / "npm.cmd",
        Path(os.environ.get("PROGRAMFILES(X86)", "")) / "nodejs" / "npm.cmd",
        Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "nodejs" / "npm.cmd",
    ]
    for p in node_paths:
        if p.exists():
            return str(p)
    return None

npm_cmd = find_npm()

if args.rebuild or input("\n  Lancer npm run build maintenant ? (o/N) : ").strip().lower() in ("o", "oui", "y", "yes"):
    step("8/8", "Rebuild du dashboard (1-2 minutes)...")
    if not npm_cmd:
        err("npm introuvable. Lancez manuellement :")
        print(f"    cd \"{web_dir}\"")
        print("    npm run build")
    else:
        ok(f"npm trouve : {npm_cmd}")
        os.chdir(web_dir)
        # Verifier que node_modules existe
        if not (web_dir / "node_modules").exists():
            info("Installation des dependances npm...")
            subprocess.run([npm_cmd, "install", "--silent"], check=False)
        result = subprocess.run([npm_cmd, "run", "build"], capture_output=False, shell=False)
        if result.returncode == 0:
            ok("Build termine avec succes !")
        else:
            err("Le build a echoue. Verifiez les erreurs ci-dessus.")
else:
    info("Rebuild ignore. Lancez manuellement :")
    print(f"    cd \"{web_dir}\"")
    print("    npm run build")

print()
print("  ============================================================")
print("  PULSAR -- Patch complet")
print("  ============================================================")
print()
print("  Couleurs : bleu nuit medical #020d1a + cyan #00d4ff")
print("  Titre    : PULSAR -- Systeme Agentique Medical")
print("  Footer   : DSIO CHU de Guyane")
print("  Banner   : PULSAR (CLI)")
print()
print("  Lancez : pulsar dashboard")
print("  Puis rechargez : Ctrl+F5")
print()
