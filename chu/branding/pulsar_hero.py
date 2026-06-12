#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Hero de marque (art Braille haute résolution)
======================================================
Génère un PULSAR rayonnant : un cœur brillant, des faisceaux qui irradient
(le pulsar émet ses impulsions) et des anneaux concentriques, en art Braille
(résolution 2×4 points par caractère, comme la caducée Hermes), avec dégradé
cyan→bleu et la croix rouge médicale au centre. Plus un wordmark PULSAR en
lettres-blocs.

    python3 chu/branding/pulsar_hero.py          # aperçu texte
"""
from __future__ import annotations
import math

# --- Toile Braille : chaque cellule code 2 (large) × 4 (haut) points ---
# Disposition des bits Unicode (offset 0x2800) :
#   (0,0)=0x01 (1,0)=0x08
#   (0,1)=0x02 (1,1)=0x10
#   (0,2)=0x04 (1,2)=0x20
#   (0,3)=0x40 (1,3)=0x80
_BITS = ((0x01, 0x08), (0x02, 0x10), (0x04, 0x20), (0x40, 0x80))


class Braille:
    def __init__(self, w_cells: int, h_cells: int):
        self.wc, self.hc = w_cells, h_cells
        self.W, self.H = w_cells * 2, h_cells * 4
        self.cells = [[0] * w_cells for _ in range(h_cells)]

    def set(self, x: float, y: float):
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < self.W and 0 <= yi < self.H:
            self.cells[yi // 4][xi // 2] |= _BITS[yi % 4][xi % 2]

    def rows(self):
        return ["".join(chr(0x2800 + c) if c else " " for c in row) for row in self.cells]


def build_hero() -> Braille:
    W, H = 34, 16                      # cellules
    b = Braille(W, H)
    cx, cy = b.W / 2, b.H / 2
    ASPECT = 1.0                       # points Braille ~ carrés

    # Anneaux concentriques (l'onde)
    for R in (10, 17, 24, 30):
        steps = int(2 * math.pi * R) + 8
        for i in range(steps):
            a = 2 * math.pi * i / steps
            b.set(cx + R * math.cos(a), cy + R * math.sin(a) * ASPECT)

    # Faisceaux qui irradient (8 branches) — le pouls du pulsar
    for k in range(8):
        a = math.pi * k / 4
        for r in range(3, 32):
            # branches plus denses près du cœur, pointillées au loin
            if r < 12 or (r % 2 == 0):
                b.set(cx + r * math.cos(a), cy + r * math.sin(a) * ASPECT)

    # Cœur brillant (disque plein)
    for yy in range(-3, 4):
        for xx in range(-4, 5):
            if xx * xx + (yy * 2) ** 2 <= 14:
                b.set(cx + xx, cy + yy)
    return b


# --- Wordmark PULSAR en lettres-blocs (5 lignes) ---
_FONT = {
    "P": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔═══╝ ", "██║     "],
    "U": ["██╗   ██╗", "██║   ██║", "██║   ██║", "██║   ██║", "╚██████╔╝"],
    "L": ["██╗     ", "██║     ", "██║     ", "██║     ", "███████╗"],
    "S": ["███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║"],
    "A": [" █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║"],
    "R": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║"],
}


def wordmark(text="PULSAR"):
    lines = ["", "", "", "", ""]
    for ch in text:
        g = _FONT.get(ch, ["        "] * 5)
        for i in range(5):
            lines[i] += g[i] + " "
    return lines


def render_markup():
    """Renvoie la liste de lignes (balises rich) : pulsar Braille + croix rouge + wordmark."""
    hero = build_hero().rows()
    grad = ["#7fe9ff", "#5fd2ff", "#3bb8ff", "#1f9eff", "#1f9eff", "#3bb8ff",
            "#5fd2ff", "#7fe9ff", "#7fe9ff", "#5fd2ff", "#3bb8ff", "#1f9eff",
            "#3bb8ff", "#5fd2ff", "#7fe9ff", "#9af1ff"]
    out = []
    mid = len(hero) // 2
    for i, line in enumerate(hero):
        color = grad[i % len(grad)]
        if i == mid:                    # croix rouge au cœur (markup propre)
            j = len(line) // 2
            out.append(f"[bold {color}]{line[:j]}[/][bold red]✚[/][bold {color}]{line[j + 1:]}[/]")
            continue
        out.append(f"[bold {color}]{line}[/]")
    out.append("")
    for wl in wordmark("PULSAR"):
        out.append(f"[bold #3bb8ff]{wl}[/]")
    out.append("[dim #7fe9ff]              D S I O  ·  C H U   d e   G u y a n e[/]")
    return out


if __name__ == "__main__":
    import re
    for l in render_markup():
        print(re.sub(r"\[/?[^\]]*\]", "", l))
