#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Animation d'accueil « radar »
======================================
Écran radar de TAILLE FIXE : cercle radar + croix rouge + crosshair restent
immobiles ; seul un anneau d'impulsion s'élargit du cœur vers le bord, en
boucle. Aucun changement d'alignement. Incarne le nom (pulsar = pulsation) et
le principe fondateur : « Une pulsation régulière réveille des agents vigilants. »

    python3 chu/branding/pulse_intro.py            # storyboard
    python3 chu/branding/pulse_intro.py --animate  # animation terminal

Couleurs (rich) : ✚ rouge ; cadre radar cyan sombre ; impulsion cyan vif.
"""
from __future__ import annotations
import math
import sys
import time

W, H = 33, 15            # scène FIXE (cellules)
CX, CY = W // 2, H // 2  # centre
ASPECT = 2.05            # cellule ~2x plus haute que large -> cercles ronds
ROUT = 13.0              # rayon du cercle radar (unités x)

PULSES = [2.0, 3.5, 5.0, 6.5, 8.0, 9.5, 11.0, 12.5]  # rayons successifs de l'onde


def _grid():
    return [[" "] * W for _ in range(H)]


def _ring(g, R, glyph, overwrite=False):
    steps = int(2 * math.pi * R) + 16
    for i in range(steps):
        a = 2 * math.pi * i / steps
        xi = int(round(CX + R * math.cos(a)))
        yi = int(round(CY + (R / ASPECT) * math.sin(a)))
        if 0 <= yi < H and 0 <= xi < W and (overwrite or g[yi][xi] == " "):
            g[yi][xi] = glyph


def _crosshair(g):
    for x in range(W):
        if abs(x - CX) <= ROUT and g[CY][x] == " ":
            g[CY][x] = "·"
    for y in range(H):
        if abs((y - CY) * ASPECT) <= ROUT and g[y][CX] == " ":
            g[y][CX] = "·"


def _radar(rpulse: float):
    g = _grid()
    _ring(g, ROUT, "·")          # cercle radar (fixe, sombre)
    _crosshair(g)                 # crosshair (fixe, sombre)
    _ring(g, rpulse, "•", overwrite=True)   # impulsion (mobile, vif)
    g[CY][CX] = "✚"              # croix rouge au cœur (fixe)
    return g


def _colorize(grid):
    out = []
    for row in grid:
        s = "".join(row)
        s = s.replace("✚", "[bold red]✚[/]")
        s = s.replace("•", "[bold #3bdcff]•[/]")
        s = s.replace("·", "[#1d5e78]·[/]")
        out.append(s)
    return out


def _build_frames():
    return [_colorize(_radar(r)) for r in PULSES]


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
    try:
        while True:
            for r, frame in enumerate(FRAMES):
                sys.stdout.write(clear)
                sys.stdout.flush()
                _render(frame, console)
                time.sleep(0.12 if r < len(FRAMES) - 1 else 0.6)
    except KeyboardInterrupt:
        pass


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
