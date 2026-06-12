#!/usr/bin/env python3
"""
PULSAR — Animation d'accueil « pulsation »
==========================================
Art ASCII ANIMÉ : une onde radiale rayonne depuis la croix rouge médicale
(CHU), s'élargit en anneaux ronds, porte le wordmark PULSAR, puis se résout
en bloc d'identité. Incarne le nom (pulsar = pulsation) et le principe
fondateur : « Une pulsation régulière réveille des agents vigilants. »

    python3 chu/branding/pulse_intro.py            # storyboard (frames figées)
    python3 chu/branding/pulse_intro.py --animate  # animation dans le terminal

Couleurs (rich) : ✚ rouge, anneaux cyan (vifs au cœur, doux au bord),
wordmark cyan vif. Sans rich : repli texte brut.
"""
from __future__ import annotations
import math
import sys
import time

W, H = 29, 11          # largeur / hauteur de la scène
CX, CY = W // 2, H // 2
ASPECT = 2.05          # une cellule est ~2x plus haute que large -> anneaux ronds

GLYPH_NEAR = "•"       # anneau proche (dense)
GLYPH_FAR = "·"        # anneau lointain (léger)


def _blank():
    return [[" "] * W for _ in range(H)]


def _ring(radius: float, soft: bool = False):
    g = _blank()
    glyph = GLYPH_FAR if soft else GLYPH_NEAR
    for y in range(H):
        for x in range(W):
            dx = x - CX
            dy = (y - CY) * ASPECT
            if abs(math.hypot(dx, dy) - radius) < 0.95:
                g[y][x] = glyph
    g[CY][CX] = "✚"
    return g


def _overlay_center(g, text):
    start = CX - len(text) // 2
    for i, ch in enumerate(text):
        x = start + i
        if 0 <= x < W:
            g[CY][x] = ch
    return g


def _box():
    """Bloc d'identité final (compact), avec la croix rouge au sommet."""
    return [
        "[bold red]              ✚[/]",
        "[bold #00d4ff]       ╔══════════════════╗[/]",
        "[bold #00d4ff]       ║  PULSAR  DSIO    ║[/]",
        "[bold #00d4ff]       ║  CHU de Guyane   ║[/]",
        "[bold #00d4ff]       ╚══════════════════╝[/]",
    ]


def _colorize(grid):
    out = []
    for row in grid:
        s = "".join(row)
        s = s.replace("✚", "[bold red]✚[/]")
        s = s.replace("•", "[#00d4ff]•[/]")
        s = s.replace("·", "[dim cyan]·[/]")
        # wordmark si présent au centre
        if "PULSAR" in s:
            s = s.replace("PULSAR", "[bold #00d4ff]PULSAR[/]")
        out.append(s)
    return out


def _build_frames():
    frames = []
    # battement 1 : onde courte
    for r in (1.5, 4.0, 6.5):
        frames.append(_colorize(_ring(r)))
    # battement 2 : onde pleine + anneau doux trailing
    for r in (2.0, 5.0, 8.0, 11.0):
        frames.append(_colorize(_ring(r)))
    # l'onde porte le nom
    g = _ring(11.5, soft=True)
    _overlay_center(g, "PULSAR")
    frames.append(_colorize(g))
    # résolution
    frames.append(_box())
    return frames


FRAMES = _build_frames()


def _render(frame, console):
    if console:
        console.print("\n".join(frame))
    else:
        import re
        for line in frame:
            print(re.sub(r"\[/?[^\]]*\]", "", line))


def animate(console):
    clear = "\033[2J\033[H"
    rythme = [0.32, 0.22, 0.30, 0.30, 0.22, 0.18, 0.16, 0.45, 0.0]
    for i, frame in enumerate(FRAMES):
        sys.stdout.write(clear)
        sys.stdout.flush()
        _render(frame, console)
        time.sleep(rythme[i] if i < len(rythme) else 0.25)


def storyboard(console):
    for i, frame in enumerate(FRAMES, 1):
        if console:
            console.print(f"[dim]— frame {i}/{len(FRAMES)} —[/]")
        else:
            print(f"— frame {i}/{len(FRAMES)} —")
        _render(frame, console)
        print()


def main():
    try:
        from rich.console import Console
        console = Console()
    except ImportError:
        console = None
    (animate if "--animate" in sys.argv else storyboard)(console)


if __name__ == "__main__":
    main()
