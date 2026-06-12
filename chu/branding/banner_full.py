#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR — Bannière unifiée (radar vivant + wordmark + infos), pilotée par le skin
================================================================================
Une SEULE bannière, comme Hermes : un pulsar-radar qui pulse (animé), le
wordmark PULSAR en lettres-blocs, et un panneau d'infos (modèle, contexte,
chemin, fonctions CHU). Les couleurs viennent de la PALETTE du skin actif —
elles changent donc avec le thème. La croix rouge médicale reste rouge (constante
d'identité CHU).

Palettes = couleurs réelles des skins (banner_accent / banner_title / banner_dim
/ banner_text / banner_border).
"""
from __future__ import annotations
import math

W, H = 33, 13
CX, CY = W // 2, H // 2
ASPECT = 2.05
ROUT = 12.0
PULSES = [2.0, 3.5, 5.0, 6.5, 8.0, 9.5, 11.0]

# Palettes issues des skins (cross = rouge médical, constante)
PALETTES = {
    "chu-guyane": dict(label="Bleu médical CHU", bg="#0a1422",
                       accent="#90CAF9", title="#42A5F5", dim="#1976D2",
                       text="#E3F2FD", border="#1565C0", cross="#EF5350"),
    "pulsar": dict(label="Pulsar cyan", bg="#070f18",
                   accent="#3bdcff", title="#7fe9ff", dim="#1d5e78",
                   text="#dff6ff", border="#1f9eff", cross="#ff5252"),
    "ambre": dict(label="Ambre (Hermes)", bg="#140f06",
                  accent="#FFBF00", title="#FFD700", dim="#8a6d10",
                  text="#FFF8DC", border="#CD7F32", cross="#DD4A3A"),
    "jour": dict(label="Clair (jour)", bg="#eef3f8",
                 accent="#1565C0", title="#0D47A1", dim="#7d93a6",
                 text="#102027", border="#1565C0", cross="#D32F2F"),
}

_FONT = {
    "P": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔═══╝ ", "██║     "],
    "U": ["██╗   ██╗", "██║   ██║", "██║   ██║", "██║   ██║", "╚██████╔╝"],
    "L": ["██╗     ", "██║     ", "██║     ", "██║     ", "███████╗"],
    "S": ["███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║"],
    "A": [" █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║"],
    "R": ["██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║"],
}


def _wordmark():
    lines = ["", "", "", "", ""]
    for ch in "PULSAR":
        g = _FONT[ch]
        for i in range(5):
            lines[i] += g[i] + " "
    return [l.rstrip() for l in lines]


WM = _wordmark()
WM_W = max(len(l) for l in WM)


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


def _radar(rpulse):
    g = _grid()
    _ring(g, ROUT, "·")
    for x in range(W):
        if abs(x - CX) <= ROUT and g[CY][x] == " ":
            g[CY][x] = "·"
    for y in range(H):
        if abs((y - CY) * ASPECT) <= ROUT and g[y][CX] == " ":
            g[y][CX] = "·"
    _ring(g, rpulse, "•", overwrite=True)
    # grosse croix rouge médicale au cœur (marqueur 'X' -> colorée ensuite)
    for dx in (-2, -1, 0, 1, 2):
        g[CY][CX + dx] = "X"
    for dy in (-1, 1):
        g[CY + dy][CX] = "X"
    return g


def _center(s, width):
    pad = max(0, (width - len(s)) // 2)
    return " " * pad + s


def banner(palette, rpulse, info=None):
    p = PALETTES[palette]
    full_w = max(W, WM_W, 60)
    radar = _radar(rpulse)
    out = []
    radar_pad = (full_w - W) // 2
    for row in radar:
        s = "".join(row)
        s = s.replace("X", f"[/][bold {p['cross']}]█[/][bold {p['accent']}]")
        s = s.replace("•", f"[/][bold {p['accent']}]•[/][bold {p['dim']}]")
        s = s.replace("·", f"[/][{p['dim']}]·[/][bold {p['dim']}]")
        out.append(f"[bold {p['dim']}]{' ' * radar_pad}{s}[/]")
    out.append("")
    for wl in WM:
        out.append(f"[bold {p['title']}]{_center(wl, full_w)}[/]")
    out.append("")
    info = info or default_info()
    for line, tags in info:
        out.append(_center_markup(line, tags, full_w, p))
    return out


def default_info():
    # (texte_brut, liste de (segment, role)) — role -> couleur de la palette
    return [
        ("Hermes-3-Llama-3.1-70B · 128k context · DSIO — CHU de Guyane",
         [("Hermes-3-Llama-3.1-70B", "accent"), (" · ", "dim"),
          ("128k context", "text"), (" · ", "dim"), ("DSIO — CHU de Guyane", "dim")]),
        ("✚ 6 agents CHU · Privacy Engine RGPD · Audit ISO 27001",
         [("✚", "cross"), (" 6 agents CHU", "text"), (" · ", "dim"),
          ("Privacy Engine RGPD", "text"), (" · ", "dim"), ("Audit ISO 27001", "text")]),
        ("~/projets/pulsar-chu", [("~/projets/pulsar-chu", "dim")]),
        ("MERI William · Licence Apache 2.0 · libre de droit",
         [("MERI William", "text"), (" · ", "dim"),
          ("Licence Apache 2.0", "accent"), (" · ", "dim"), ("libre de droit", "dim")]),
    ]


def _center_markup(plain, tags, width, p):
    pad = max(0, (width - len(plain)) // 2)
    parts = [" " * pad]
    for seg, role in tags:
        color = p[role]
        bold = "bold " if role in ("accent", "cross") else ""
        parts.append(f"[{bold}{color}]{seg}[/]")
    return "".join(parts)


def frames(palette):
    return [banner(palette, r) for r in PULSES]


if __name__ == "__main__":
    import re, sys
    pal = sys.argv[1] if len(sys.argv) > 1 else "chu-guyane"
    for l in banner(pal, 6.5):
        print(re.sub(r"\[/?[^\]]*\]", "", l))
