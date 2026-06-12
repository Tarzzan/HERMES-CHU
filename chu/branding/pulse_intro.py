#!/usr/bin/env python3
"""
PULSAR — Animation d'accueil « pulsation »
==========================================
Art ASCII ANIMÉ : une pulsation rayonne depuis la croix rouge médicale (CHU),
puis fait apparaître le wordmark PULSAR. Incarne le nom (pulsar = pulsation)
et le principe fondateur : « Une pulsation régulière réveille des agents
vigilants. »

Démo storyboard (étapes figées) :
    python3 chu/branding/pulse_intro.py

Jouer l'animation dans un terminal :
    python3 chu/branding/pulse_intro.py --animate

Couleurs (balises rich) : ✚ en rouge, anneaux en cyan, wordmark en cyan vif.
Sans rich, repli en texte brut.
"""
from __future__ import annotations
import sys
import time

# Chaque frame : (lignes). Balises rich pour la couleur ; centrées sur la croix.
FRAMES = [
    # 1 — la croix seule (le cœur CHU)
    [r"                     ",
     r"          [bold red]✚[/]          ",
     r"                     "],
    # 2 — premier anneau
    [r"                     ",
     r"         [cyan]·[/][bold red]✚[/][cyan]·[/]         ",
     r"                     "],
    # 3 — l'onde s'écarte
    [r"          [cyan]·[/]          ",
     r"        [cyan]([/] [bold red]✚[/] [cyan])[/]        ",
     r"          [cyan]·[/]          "],
    # 4 — pulsation pleine
    [r"        [cyan].·°·.[/]        ",
     r"      [cyan]((  [/][bold red]✚[/][cyan]  ))[/]      ",
     r"        [cyan]`·°·`[/]        "],
    # 5 — l'onde porte le nom
    [r"      [cyan].·°‹ ›°·.[/]      ",
     r"     [cyan](( [/][bold #00d4ff]PULSAR[/][cyan] ))[/]     ",
     r"      [cyan]`·°‹ ›°·`[/]      "],
    # 6 — résolution : le bloc d'identité
    [r"          [bold red]✚[/]          ",
     r"  [bold #00d4ff]╔══════════════════╗[/]",
     r"  [bold #00d4ff]║  PULSAR  DSIO    ║[/]",
     r"  [bold #00d4ff]║  CHU de Guyane   ║[/]",
     r"  [bold #00d4ff]╚══════════════════╝[/]"],
]


def _render(frame, console):
    if console:
        console.print("\n".join(frame))
    else:
        import re
        for line in frame:
            print(re.sub(r"\[/?[^\]]*\]", "", line))


def animate(console):
    # Efface l'écran entre les frames pour l'effet de pulsation.
    clear = "\033[2J\033[H"
    for i, frame in enumerate(FRAMES):
        sys.stdout.write(clear)
        sys.stdout.flush()
        _render(frame, console)
        time.sleep(0.45 if i < len(FRAMES) - 1 else 0.0)


def storyboard(console):
    for i, frame in enumerate(FRAMES, 1):
        label = f"--- étape {i}/{len(FRAMES)} ---"
        if console:
            console.print(f"[dim]{label}[/]")
        else:
            print(label)
        _render(frame, console)
        print()


def main():
    try:
        from rich.console import Console
        console = Console()
    except ImportError:
        console = None
    if "--animate" in sys.argv:
        animate(console)
    else:
        storyboard(console)


if __name__ == "__main__":
    main()
