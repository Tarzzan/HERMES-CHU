"""
pulsar-tray.py — Icône systray PULSAR pour Windows
DSIO - CHU de Guyane | William MERI

Fonctionnalités :
  - Icône dans la barre des tâches (systray)
  - Menu : Ouvrir le dashboard / Arrêter PULSAR / À propos / Quitter
  - Démarre le serveur pulsar dashboard si non actif
  - Ouvre le navigateur sur http://localhost:9119
"""

import sys
import os
import subprocess
import threading
import webbrowser
import time
import socket
from pathlib import Path

try:
    import pystray
    from PIL import Image, ImageDraw
except ImportError:
    # Installation automatique si absent
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pystray", "pillow", "--quiet"])
    import pystray
    from PIL import Image, ImageDraw

# ── Configuration ──────────────────────────────────────────────────────────────
PULSAR_PORT   = 9119
PULSAR_URL    = f"http://localhost:{PULSAR_PORT}"
PULSAR_HOME   = Path(os.environ.get("LOCALAPPDATA", "")) / "hermes" / "hermes-chu"
VENV_PULSAR   = PULSAR_HOME / ".venv" / "Scripts" / "pulsar.exe"

# Processus serveur global
_server_proc = None


# ── Icône PULSAR générée en mémoire (carré bleu nuit avec "P") ─────────────────
def creer_icone(couleur_fond="#0D1B2A", couleur_texte="#00C9FF"):
    """Génère une icône 64x64 avec la lettre P sur fond bleu nuit."""
    img = Image.new("RGB", (64, 64), couleur_fond)
    d   = ImageDraw.Draw(img)
    # Cercle de fond
    d.ellipse([4, 4, 60, 60], fill="#1A3A5C", outline="#00C9FF", width=2)
    # Lettre P centrée
    d.text((20, 14), "P", fill=couleur_texte)
    return img


def icone_arret():
    """Icône grisée quand le serveur est arrêté."""
    return creer_icone(couleur_fond="#1C1C1C", couleur_texte="#888888")


# ── Vérification du serveur ────────────────────────────────────────────────────
def serveur_actif():
    """Retourne True si quelque chose écoute sur PULSAR_PORT."""
    try:
        with socket.create_connection(("localhost", PULSAR_PORT), timeout=1):
            return True
    except OSError:
        return False


# ── Démarrage du serveur ───────────────────────────────────────────────────────
def demarrer_serveur():
    global _server_proc
    if serveur_actif():
        return  # Déjà actif

    pulsar_exe = str(VENV_PULSAR) if VENV_PULSAR.exists() else "pulsar"

    _server_proc = subprocess.Popen(
        [pulsar_exe, "dashboard", "--no-browser"],
        cwd=str(PULSAR_HOME),
        creationflags=subprocess.CREATE_NO_WINDOW,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Attendre que le serveur soit prêt (max 15s)
    for _ in range(30):
        if serveur_actif():
            break
        time.sleep(0.5)


def arreter_serveur():
    global _server_proc
    if _server_proc and _server_proc.poll() is None:
        _server_proc.terminate()
        _server_proc = None
    # Tuer aussi tout processus pulsar.exe restant
    subprocess.run(
        ["taskkill", "/F", "/IM", "pulsar.exe"],
        creationflags=subprocess.CREATE_NO_WINDOW,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


# ── Actions du menu ────────────────────────────────────────────────────────────
def action_ouvrir(icon, item):
    """Ouvre le dashboard dans le navigateur, démarre le serveur si besoin."""
    def _ouvrir():
        if not serveur_actif():
            icon.icon  = creer_icone(couleur_fond="#1A3A5C", couleur_texte="#FFD700")
            icon.title = "PULSAR — Démarrage..."
            demarrer_serveur()
        icon.icon  = creer_icone()
        icon.title = "PULSAR — En cours"
        webbrowser.open(PULSAR_URL)
    threading.Thread(target=_ouvrir, daemon=True).start()


def action_arreter(icon, item):
    """Arrête le serveur PULSAR."""
    def _arreter():
        arreter_serveur()
        icon.icon  = icone_arret()
        icon.title = "PULSAR — Arrêté"
    threading.Thread(target=_arreter, daemon=True).start()


def action_apropos(icon, item):
    import ctypes
    ctypes.windll.user32.MessageBoxW(
        0,
        "PULSAR v2.3.0\n\nPlateforme Unifiée de Liaison,\nde Surveillance et d'Assistance\nen temps Réel\n\nDSIO - CHU de Guyane\nWilliam MERI\n\nhttps://github.com/Tarzzan/PULSAR-CHU",
        "À propos de PULSAR",
        0x40,  # MB_ICONINFORMATION
    )


def action_quitter(icon, item):
    arreter_serveur()
    icon.stop()


# ── Construction du menu ───────────────────────────────────────────────────────
def construire_menu():
    return pystray.Menu(
        pystray.MenuItem("Ouvrir PULSAR",   action_ouvrir,  default=True),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("Arrêter le serveur", action_arreter),
        pystray.Menu.SEPARATOR,
        pystray.MenuItem("À propos",        action_apropos),
        pystray.MenuItem("Quitter",         action_quitter),
    )


# ── Point d'entrée ─────────────────────────────────────────────────────────────
def main():
    # Démarrer le serveur en arrière-plan au lancement
    threading.Thread(target=demarrer_serveur, daemon=True).start()

    # Ouvrir le navigateur après démarrage
    def _ouvrir_navigateur():
        time.sleep(3)
        if serveur_actif():
            webbrowser.open(PULSAR_URL)
    threading.Thread(target=_ouvrir_navigateur, daemon=True).start()

    # Créer l'icône systray
    icon = pystray.Icon(
        name="PULSAR",
        icon=creer_icone(),
        title="PULSAR — DSIO CHU de Guyane",
        menu=construire_menu(),
    )

    icon.run()


if __name__ == "__main__":
    main()
