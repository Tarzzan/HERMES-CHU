#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
# -*- coding: utf-8 -*-
"""
patch_pulsar_full.py — Patch global PULSAR v3.0
================================================
Remplace TOUTES les references a Hermes Agent / Nous Research par
PULSAR / DSIO - CHU de Guyane dans les sources hermes-agent.

Usage (Windows) :
    python patch_pulsar_full.py

Le script detecte automatiquement le chemin hermes depuis %LOCALAPPDATA%.
"""

import os
import re
import sys
import shutil
from pathlib import Path

# ============================================================
# CONFIGURATION
# ============================================================

HERMES_HOME = Path(os.environ.get("LOCALAPPDATA", "")) / "hermes"
WEB_SRC     = HERMES_HOME / "hermes-agent" / "web" / "src"
HERMES_CLI  = HERMES_HOME / "hermes_cli"

PULSAR_DOCS_URL = "https://github.com/Tarzzan/PULSAR-CHU/wiki"
PULSAR_GITHUB   = "https://github.com/Tarzzan/PULSAR-CHU"
CHU_ORG         = "DSIO - CHU de Guyane"
CHU_ORG_URL     = "https://www.chu-guyane.fr"
PULSAR_VERSION  = "2.3.0"

# ============================================================
# UTILITAIRES
# ============================================================

def patch_file(path: Path, replacements: list[tuple[str, str]], label: str = "") -> bool:
    """Applique une liste de (ancien, nouveau) dans le fichier. Retourne True si modifie."""
    if not path.exists():
        print(f"  [SKIP] {path.name} — fichier introuvable")
        return False
    original = path.read_text(encoding="utf-8", errors="replace")
    content  = original
    for old, new in replacements:
        content = content.replace(old, new)
    if content != original:
        # Backup
        bak = path.with_suffix(path.suffix + ".bak_pulsar")
        if not bak.exists():
            shutil.copy2(path, bak)
        path.write_text(content, encoding="utf-8")
        tag = f" [{label}]" if label else ""
        print(f"  [OK]{tag} {path.relative_to(HERMES_HOME)}")
        return True
    else:
        print(f"  [--] {path.relative_to(HERMES_HOME)} (rien a changer)")
        return False


def patch_regex(path: Path, pattern: str, replacement: str, flags=0) -> bool:
    """Applique un remplacement regex dans le fichier."""
    if not path.exists():
        return False
    original = path.read_text(encoding="utf-8", errors="replace")
    content  = re.sub(pattern, replacement, original, flags=flags)
    if content != original:
        bak = path.with_suffix(path.suffix + ".bak_pulsar")
        if not bak.exists():
            shutil.copy2(path, bak)
        path.write_text(content, encoding="utf-8")
        print(f"  [OK/regex] {path.relative_to(HERMES_HOME)}")
        return True
    return False


# ============================================================
# PATCH 1 — index.html (titre onglet navigateur)
# ============================================================

def patch_index_html():
    print("\n[1] index.html — titre navigateur")
    f = HERMES_HOME / "hermes-agent" / "web" / "index.html"
    patch_file(f, [
        ("<title>Hermes Agent - Dashboard</title>",
         "<title>PULSAR - DSIO CHU de Guyane</title>"),
        ("Hermes Agent", "PULSAR"),
    ], "HTML")


# ============================================================
# PATCH 2 — i18n/fr.ts — francisation + branding PULSAR
# ============================================================

def patch_i18n_fr():
    print("\n[2] i18n/fr.ts — branding + francisation")
    f = WEB_SRC / "i18n" / "fr.ts"
    replacements = [
        # Branding principal
        ('"Hermes Agent"',          '"PULSAR"'),
        ('"HA"',                    '"PLS"'),
        ('"Nous Research"',         f'"{CHU_ORG}"'),
        # Boutons de mise a jour
        ('"Mettre a jour Hermes"',  '"Mettre a jour PULSAR"'),
        ('"Mise a jour de Hermes"', '"Mise a jour de PULSAR"'),
        ('Mettre \u00e0 jour Hermes',  'Mettre \u00e0 jour PULSAR'),
        ('Mise \u00e0 jour de Hermes', 'Mise \u00e0 jour de PULSAR'),
        # Plugins
        ('plugins Hermes (parit\u00e9 avec `hermes plugins`).',
         'plugins PULSAR (parit\u00e9 avec `pulsar plugins`).'),
        ('~/.hermes/plugins/', '~/.pulsar/plugins/'),
        # Skills
        ('~/.hermes/skills/', '~/.pulsar/skills/'),
        # Config
        ('~/.hermes/config.yaml', '~/.pulsar/config.yaml'),
        # Achievements
        ('"Hermes Achievements"',   '"PULSAR Succes"'),
        ('Badges Hermes',           'Badges PULSAR'),
        ('historique des sessions Hermes',
         'historique des sessions PULSAR'),
        ("l'historique des sessions Hermes",
         "l'historique des sessions PULSAR"),
        ('utilisez Hermes davantage', 'utilisez PULSAR davantage'),
        ("Dès qu'Hermes détecte",    "Dès que PULSAR détecte"),
        ("Hermes analyse l'historique",
         "PULSAR analyse l'historique"),
        # Tweet (reste en anglais mais avec PULSAR)
        ('in Hermes Agent', 'avec PULSAR'),
        # Divers
        ('Hermes', 'PULSAR'),
        ('hermes', 'pulsar'),
    ]
    patch_file(f, replacements, "i18n/fr")


# ============================================================
# PATCH 3 — i18n/en.ts — branding PULSAR (anglais)
# ============================================================

def patch_i18n_en():
    print("\n[3] i18n/en.ts — branding PULSAR")
    f = WEB_SRC / "i18n" / "en.ts"
    replacements = [
        ('"Hermes Agent"',          '"PULSAR"'),
        ('"HA"',                    '"PLS"'),
        ('"Nous Research"',         f'"{CHU_ORG}"'),
        ('"Update Hermes"',         '"Update PULSAR"'),
        ('"Updating Hermes\u2026"', '"Updating PULSAR\u2026"'),
        ('Hermes plugins (`hermes plugins` parity).',
         'PULSAR plugins (`pulsar plugins` parity).'),
        ('~/.hermes/plugins/', '~/.pulsar/plugins/'),
        ('~/.hermes/skills/', '~/.pulsar/skills/'),
        ('~/.hermes/config.yaml', '~/.pulsar/config.yaml'),
        ('"Hermes Achievements"',   '"PULSAR Achievements"'),
        ('Collectible Hermes badges', 'Collectible PULSAR badges'),
        ('Scanning Hermes session history', 'Scanning PULSAR session history'),
        ('run Hermes more', 'use PULSAR more'),
        ('Once Hermes sees', 'Once PULSAR sees'),
        ('Hermes is scanning', 'PULSAR is scanning'),
        ('in Hermes Agent', 'with PULSAR'),
        ('Hermes', 'PULSAR'),
        ('hermes', 'pulsar'),
    ]
    patch_file(f, replacements, "i18n/en")


# ============================================================
# PATCH 4 — DocsPage.tsx — remplacer l'iframe nousresearch
# ============================================================

def patch_docs_page():
    print("\n[4] DocsPage.tsx — remplacer l'iframe Hermes par page PULSAR locale")
    f = WEB_SRC / "pages" / "DocsPage.tsx"
    new_content = '''import { useLayoutEffect } from "react";
import { ExternalLink } from "lucide-react";
import { useI18n } from "@/i18n";
import { usePageHeader } from "@/contexts/usePageHeader";
import { cn } from "@/lib/utils";
import { PluginSlot } from "@/plugins";

export const PULSAR_DOCS_URL = "''' + PULSAR_DOCS_URL + '''";

const DS_BUTTON_OUTLINED_LINK_CN = cn(
  "group relative inline-grid grid-cols-[auto_1fr_auto] items-center",
  "px-[.9em_.75em] py-[1.25em] gap-2",
  "leading-0 font-bold tracking-[0.2em] uppercase",
  "text-midground bg-transparent shadow-midground",
  "shadow-[inset_-1px_-1px_0_0_#00000080,inset_1px_1px_0_0_#ffffff80]",
);

export default function DocsPage() {
  const { t } = useI18n();
  const { setEnd } = usePageHeader();
  useLayoutEffect(() => {
    setEnd(
      <a
        href={PULSAR_DOCS_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={DS_BUTTON_OUTLINED_LINK_CN}
      >
        <ExternalLink className="size-3.5" />
        {t.app.openDocumentation}
      </a>,
    );
    return () => {
      setEnd(null);
    };
  }, [setEnd, t]);

  return (
    <div
      className={cn(
        "flex min-h-0 w-full min-w-0 flex-1 flex-col items-center justify-center",
        "pt-1 sm:pt-2 px-6",
      )}
    >
      <PluginSlot name="docs:top" />
      <div className={cn(
        "w-full max-w-3xl rounded-lg border border-current/20 p-8",
        "bg-background/60 backdrop-blur-sm",
        "flex flex-col gap-6",
      )}>
        {/* En-tete PULSAR */}
        <div className="flex flex-col gap-2">
          <h1 className="text-3xl font-bold tracking-tight text-midground uppercase">
            PULSAR
          </h1>
          <p className="text-sm text-text-tertiary tracking-widest uppercase">
            Plateforme Unifiee de Liaison, de Surveillance et d\'Assistance en temps Reel
          </p>
          <p className="text-xs text-text-tertiary">
            DSIO &mdash; CHU de Guyane &nbsp;&bull;&nbsp; v''' + PULSAR_VERSION + '''
          </p>
        </div>

        {/* Description */}
        <p className="text-sm text-text-secondary leading-relaxed">
          PULSAR est le systeme agentique medical du DSIO du CHU de Guyane.
          Il integre un moteur d\'IA avance, un Privacy Engine RGPD, six agents
          specialises (Clinique, Administratif, Logistique, Recherche, Qualite,
          Formation) et un deploiement multi-postes securise.
        </p>

        {/* Acces rapide */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <a
            href={PULSAR_DOCS_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 rounded border border-current/20 px-4 py-3 text-sm hover:bg-current/5 transition-colors"
          >
            <ExternalLink className="size-4 shrink-0" />
            <span>Documentation en ligne</span>
          </a>
          <a
            href="''' + PULSAR_GITHUB + '''"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 rounded border border-current/20 px-4 py-3 text-sm hover:bg-current/5 transition-colors"
          >
            <ExternalLink className="size-4 shrink-0" />
            <span>Depot GitHub PULSAR</span>
          </a>
          <a
            href="''' + CHU_ORG_URL + '''"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 rounded border border-current/20 px-4 py-3 text-sm hover:bg-current/5 transition-colors"
          >
            <ExternalLink className="size-4 shrink-0" />
            <span>CHU de Guyane</span>
          </a>
          <a
            href="mailto:dsio@chu-guyane.fr"
            className="flex items-center gap-2 rounded border border-current/20 px-4 py-3 text-sm hover:bg-current/5 transition-colors"
          >
            <ExternalLink className="size-4 shrink-0" />
            <span>Support DSIO</span>
          </a>
        </div>

        {/* Agents CHU */}
        <div className="flex flex-col gap-2">
          <h2 className="text-xs font-bold tracking-widest uppercase text-text-tertiary">
            Agents specialises
          </h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-xs">
            {[
              "Clinique", "Administratif", "Logistique",
              "Recherche", "Qualite", "Formation"
            ].map((agent) => (
              <span
                key={agent}
                className="rounded border border-current/15 px-3 py-1.5 text-center text-text-secondary"
              >
                {agent}
              </span>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="text-xs text-text-tertiary border-t border-current/10 pt-4">
          Developpe par William MERI &mdash; DSIO, CHU de Guyane &nbsp;&bull;&nbsp;
          Souverainete numerique &amp; conformite RGPD
        </p>
      </div>
      <PluginSlot name="docs:bottom" />
    </div>
  );
}
'''
    if not f.exists():
        print(f"  [SKIP] DocsPage.tsx introuvable")
        return
    bak = f.with_suffix(f.suffix + ".bak_pulsar")
    if not bak.exists():
        shutil.copy2(f, bak)
    f.write_text(new_content, encoding="utf-8")
    print(f"  [OK] {f.relative_to(HERMES_HOME)}")


# ============================================================
# PATCH 5 — App.tsx — "Hermes" hardcode dans la sidebar
# ============================================================

def patch_app_tsx():
    print("\n[5] App.tsx — branding sidebar + aria labels")
    f = WEB_SRC / "App.tsx"
    replacements = [
        # Nom affiché dans la sidebar (hardcodé)
        ('                  Hermes\n                  <br />\n                  Agent',
         '                  PULSAR'),
        # aria-labelledby
        ('"hermes-sidebar-plugin-nav-heading"',
         '"pulsar-sidebar-plugin-nav-heading"'),
        ('id="hermes-sidebar-plugin-nav-heading"',
         'id="pulsar-sidebar-plugin-nav-heading"'),
        # localStorage key
        ('"hermes-sidebar-collapsed"',
         '"pulsar-sidebar-collapsed"'),
    ]
    patch_file(f, replacements, "App.tsx")


# ============================================================
# PATCH 6 — SidebarFooter.tsx — lien nousresearch.com
# ============================================================

def patch_sidebar_footer():
    print("\n[6] SidebarFooter.tsx — lien organisation")
    f = WEB_SRC / "components" / "SidebarFooter.tsx"
    replacements = [
        ('href="https://nousresearch.com"',
         f'href="{CHU_ORG_URL}"'),
    ]
    patch_file(f, replacements, "SidebarFooter")


# ============================================================
# PATCH 7 — themes/presets.ts — labels themes
# ============================================================

def patch_themes_presets():
    print("\n[7] themes/presets.ts — labels des themes")
    f = WEB_SRC / "themes" / "presets.ts"
    replacements = [
        ('label: "Hermes Teal"',
         'label: "PULSAR Nuit"'),
        ('description: "Classic dark teal — the canonical Hermes look"',
         'description: "Thème sombre officiel PULSAR — bleu médical et cyan"'),
        ('label: "Hermes Teal (Large)"',
         'label: "PULSAR Nuit (Grand)"'),
        ('description: "Hermes Teal with bigger fonts and roomier spacing"',
         'description: "PULSAR Nuit avec polices agrandies et espacement confortable"'),
        ('label: "Nous Blue"',
         'label: "PULSAR Lumière"'),
        ('description: "Light mode — vivid Nous-blue accents on cream canvas"',
         'description: "Mode clair — accents teal sur fond blanc médical"'),
        # Commentaires internes
        ('the canonical Hermes look', 'le thème officiel PULSAR'),
        ('Nous-blue', 'PULSAR-teal'),
        ('nousnet-web', 'pulsar-web'),
        ('hermes-agent\'s', 'pulsar\'s'),
    ]
    patch_file(f, replacements, "presets.ts")


# ============================================================
# PATCH 8 — web_server.py — builtin themes + textes UI
# ============================================================

def patch_web_server():
    print("\n[8] web_server.py — themes builtin + textes UI")
    f = HERMES_CLI / "web_server.py"
    replacements = [
        # Titre FastAPI
        ('title="Hermes Agent"',
         'title="PULSAR - DSIO CHU de Guyane"'),
        # Themes builtin
        ('"label": "Hermes Teal"',
         '"label": "PULSAR Nuit"'),
        ('"description": "Classic dark teal — the canonical Hermes look"',
         '"description": "Theme sombre officiel PULSAR"'),
        ('"label": "Hermes Teal (Large)"',
         '"label": "PULSAR Nuit (Grand)"'),
        ('"description": "Hermes Teal with bigger fonts and roomier spacing"',
         '"description": "PULSAR Nuit avec polices agrandies"'),
        ('"label": "Nous Blue"',
         '"label": "PULSAR Lumiere"'),
        ('"description": "Light mode — vivid Nous-blue accents on cream canvas"',
         '"description": "Mode clair PULSAR"'),
        # Nous Portal → PULSAR Portal
        ('"name": "Nous Portal"',
         '"name": "PULSAR Portal"'),
        # Telegram bot name
        ('bot_name = (body.bot_name or "Hermes Agent").strip() or "Hermes Agent"',
         'bot_name = (body.bot_name or "PULSAR").strip() or "PULSAR"'),
        # Hermes Index → PULSAR Index
        ('"hermes-index": "Hermes Index"',
         '"hermes-index": "PULSAR Index"'),
        # Telegram onboarding URL
        ('_TELEGRAM_ONBOARDING_USER_AGENT = f"HermesDashboard/{__version__}"',
         '_TELEGRAM_ONBOARDING_USER_AGENT = f"PULSARDashboard/{__version__}"'),
        # OAuth gate message
        ('"via Nous Portal"',
         '"via PULSAR Portal"'),
        # Subscription URL
        ('"subscription_url": "https://portal.nousresearch.com/manage-subscription"',
         '"subscription_url": "' + PULSAR_GITHUB + '"'),
    ]
    patch_file(f, replacements, "web_server.py")


# ============================================================
# PATCH 9 — banner.py — logo ASCII + URLs
# ============================================================

PULSAR_ASCII_LOGO = r"""[bold #00d4ff]██████╗ ██╗   ██╗██╗     ███████╗ █████╗ ██████╗ [/]
[bold #00d4ff]██╔══██╗██║   ██║██║     ██╔════╝██╔══██╗██╔══██╗[/]
[#00b4d8]██████╔╝██║   ██║██║     ███████╗███████║██████╔╝[/]
[#00b4d8]██╔═══╝ ██║   ██║██║     ╚════██║██╔══██║██╔══██╗[/]
[#0096c7]██║     ╚██████╔╝███████╗███████║██║  ██║██║  ██║[/]
[#0096c7]╚═╝      ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝[/]"""

PULSAR_CADUCEUS = r"""[#00d4ff]         ╔═══════════════╗[/]
[#00d4ff]         ║  PULSAR v{ver}  ║[/]
[#00b4d8]         ║  DSIO · CHU GY ║[/]
[#0096c7]         ╚═══════════════╝[/]"""

def patch_banner():
    print("\n[9] banner.py — logo ASCII + URLs")
    f = HERMES_CLI / "banner.py"
    if not f.exists():
        print(f"  [SKIP] banner.py introuvable")
        return
    original = f.read_text(encoding="utf-8", errors="replace")
    content  = original

    # Remplacer le logo ASCII Hermes par le logo PULSAR
    # Le logo est entre HERMES_AGENT_LOGO = """ et """
    logo_pattern = r'HERMES_AGENT_LOGO = """.*?"""'
    logo_replacement = 'PULSAR_LOGO = """\n' + PULSAR_ASCII_LOGO + '\n"""'
    content = re.sub(logo_pattern, logo_replacement, content, flags=re.DOTALL)

    # Remplacer les références dans le code
    content = content.replace('HERMES_AGENT_LOGO', 'PULSAR_LOGO')

    # Caduceus → symbole PULSAR
    caduceus_pattern = r'HERMES_CADUCEUS = """.*?"""'
    caduceus_replacement = 'PULSAR_SYMBOL = """\n' + PULSAR_CADUCEUS + '\n"""'
    content = re.sub(caduceus_pattern, caduceus_replacement, content, flags=re.DOTALL)
    content = content.replace('HERMES_CADUCEUS', 'PULSAR_SYMBOL')

    # URLs
    content = content.replace(
        '_UPSTREAM_REPO_URL = "https://github.com/NousResearch/hermes-agent.git"',
        f'_UPSTREAM_REPO_URL = "{PULSAR_GITHUB}.git"'
    )
    content = content.replace(
        '_RELEASE_URL_BASE = "https://github.com/NousResearch/hermes-agent/releases/tag"',
        f'_RELEASE_URL_BASE = "{PULSAR_GITHUB}/releases/tag"'
    )
    content = content.replace(
        '"hermes-agent"',
        '"pulsar"'
    )

    if content != original:
        bak = f.with_suffix(f.suffix + ".bak_pulsar")
        if not bak.exists():
            shutil.copy2(f, bak)
        f.write_text(content, encoding="utf-8")
        print(f"  [OK] {f.relative_to(HERMES_HOME)}")
    else:
        print(f"  [--] banner.py (rien a changer)")


# ============================================================
# PATCH 10 — _parser.py — description CLI
# ============================================================

def patch_parser():
    print("\n[10] _parser.py — description CLI")
    f = HERMES_CLI / "_parser.py"
    replacements = [
        ('prog="hermes"',
         'prog="pulsar"'),
        ('description="Hermes Agent - AI assistant with tool-calling capabilities"',
         'description="PULSAR - Systeme Agentique Medical - DSIO CHU de Guyane"'),
        ('"Hermes Agent - AI assistant with tool-calling capabilities"',
         '"PULSAR - Systeme Agentique Medical - DSIO CHU de Guyane"'),
        ('description="Start an interactive chat session with Hermes Agent"',
         'description="Demarrer une session de chat avec PULSAR"'),
    ]
    patch_file(f, replacements, "_parser.py")


# ============================================================
# PATCH 11 — EnvPage.tsx — "Nous Portal" → "PULSAR Portal"
# ============================================================

def patch_env_page():
    print("\n[11] EnvPage.tsx — Nous Portal → PULSAR Portal")
    f = WEB_SRC / "pages" / "EnvPage.tsx"
    replacements = [
        ('{ prefix: "NOUS_", name: "Nous Portal", priority: 0 }',
         '{ prefix: "NOUS_", name: "PULSAR Portal", priority: 0 }'),
        ('~/.hermes/.env', '~/.pulsar/.env'),
    ]
    patch_file(f, replacements, "EnvPage.tsx")


# ============================================================
# PATCH 12 — SkillsPage.tsx — "Hermes index" → "PULSAR index"
# ============================================================

def patch_skills_page():
    print("\n[12] SkillsPage.tsx — Hermes index → PULSAR index")
    f = WEB_SRC / "pages" / "SkillsPage.tsx"
    replacements = [
        ('from the Hermes index', 'depuis l\'index PULSAR'),
        ('hermes skills search', 'pulsar skills search'),
    ]
    patch_file(f, replacements, "SkillsPage.tsx")


# ============================================================
# PATCH 13 — PluginsPage.tsx — chemins ~/.hermes
# ============================================================

def patch_plugins_page():
    print("\n[13] PluginsPage.tsx — chemins ~/.hermes")
    f = WEB_SRC / "pages" / "PluginsPage.tsx"
    replacements = [
        ('~/.hermes/plugins/', '~/.pulsar/plugins/'),
    ]
    patch_file(f, replacements, "PluginsPage.tsx")


# ============================================================
# PATCH 14 — ConfigPage.tsx — nom fichier export
# ============================================================

def patch_config_page():
    print("\n[14] ConfigPage.tsx — nom fichier export")
    f = WEB_SRC / "pages" / "ConfigPage.tsx"
    replacements = [
        ('a.download = "hermes-config.json"',
         'a.download = "pulsar-config.json"'),
    ]
    patch_file(f, replacements, "ConfigPage.tsx")


# ============================================================
# PATCH 15 — lib/api.ts — session header + storage keys
# ============================================================

def patch_lib_api():
    print("\n[15] lib/api.ts — session header + storage keys")
    f = WEB_SRC / "lib" / "api.ts"
    replacements = [
        ('"hermes.lastLocation"',   '"pulsar.lastLocation"'),
        ('"hermes.tokenReloadAttempted"', '"pulsar.tokenReloadAttempted"'),
        ('Session token not available — page must be served by the Hermes dashboard server',
         'Session token not available — page must be served by the PULSAR dashboard server'),
    ]
    patch_file(f, replacements, "lib/api.ts")


# ============================================================
# PATCH 16 — SystemActions.tsx — message Docker update
# ============================================================

def patch_system_actions():
    print("\n[16] SystemActions.tsx — message Docker update")
    f = WEB_SRC / "contexts" / "SystemActions.tsx"
    replacements = [
        ('"Updates don\'t apply inside Docker — re-pull the image instead."',
         '"Les mises a jour ne s\'appliquent pas dans Docker — re-tirez l\'image PULSAR."'),
    ]
    patch_file(f, replacements, "SystemActions.tsx")


# ============================================================
# PATCH 17 — active_sessions.py — message limite sessions
# ============================================================

def patch_active_sessions():
    print("\n[17] active_sessions.py — message limite sessions")
    f = HERMES_CLI / "active_sessions.py"
    replacements = [
        ('f"Hermes is at the active session limit ({active_count}/{max_sessions}). "',
         'f"PULSAR a atteint la limite de sessions actives ({active_count}/{max_sessions}). "'),
    ]
    patch_file(f, replacements, "active_sessions.py")


# ============================================================
# PATCH 18 — auth.py — client_id
# ============================================================

def patch_auth():
    print("\n[18] auth.py — client_id Nous")
    f = HERMES_CLI / "auth.py"
    replacements = [
        ('DEFAULT_NOUS_CLIENT_ID = "hermes-cli"',
         'DEFAULT_NOUS_CLIENT_ID = "pulsar-cli"'),
    ]
    patch_file(f, replacements, "auth.py")


# ============================================================
# RAPPORT FINAL
# ============================================================

def print_report():
    print("\n" + "=" * 60)
    print("  PATCH PULSAR v3.0 — RAPPORT FINAL")
    print("=" * 60)
    print("""
Fichiers patche avec succes. Prochaines etapes :

  1. Reconstruire le frontend :
     cd %LOCALAPPDATA%\\hermes\\hermes-agent\\web
     npm run build

  2. Relancer le dashboard :
     pulsar dashboard

  3. Verifier dans le navigateur :
     - Titre onglet : "PULSAR - DSIO CHU de Guyane"
     - Sidebar : "PULSAR" (plus "Hermes Agent")
     - Footer : "DSIO - CHU de Guyane" (plus "Nous Research")
     - Page Documentation : page PULSAR locale (plus iframe nousresearch)
     - Themes : "PULSAR Nuit", "PULSAR Lumiere"

  Les fichiers .bak_pulsar sont les sauvegardes originales.
""")


# ============================================================
# MAIN
# ============================================================

def main():
    print("=" * 60)
    print("  PATCH PULSAR v3.0 — Audit & Correction globale")
    print(f"  HERMES_HOME : {HERMES_HOME}")
    print("=" * 60)

    if not HERMES_HOME.exists():
        print(f"\n[ERREUR] HERMES_HOME introuvable : {HERMES_HOME}")
        print("Verifiez que hermes est installe dans %LOCALAPPDATA%\\hermes\\")
        sys.exit(1)

    if not WEB_SRC.exists():
        print(f"\n[ERREUR] Sources web introuvables : {WEB_SRC}")
        sys.exit(1)

    # Appliquer tous les patches
    patch_index_html()
    patch_i18n_fr()
    patch_i18n_en()
    patch_docs_page()
    patch_app_tsx()
    patch_sidebar_footer()
    patch_themes_presets()
    patch_web_server()
    patch_banner()
    patch_parser()
    patch_env_page()
    patch_skills_page()
    patch_plugins_page()
    patch_config_page()
    patch_lib_api()
    patch_system_actions()
    patch_active_sessions()
    patch_auth()

    print_report()


if __name__ == "__main__":
    main()
