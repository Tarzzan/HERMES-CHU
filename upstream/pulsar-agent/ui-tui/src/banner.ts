import type { ThemeColors } from './theme.js'

const RICH_RE = /\[(?:bold\s+)?(?:dim\s+)?(#(?:[0-9a-fA-F]{3,8}))\]([\s\S]*?)(\[\/\])/g

export function parseRichMarkup(markup: string): Line[] {
  const lines: Line[] = []

  for (const raw of markup.split('\n')) {
    const trimmed = raw.trimEnd()

    if (!trimmed) {
      lines.push(['', ' '])

      continue
    }

    const matches = [...trimmed.matchAll(RICH_RE)]

    if (!matches.length) {
      lines.push(['', trimmed])

      continue
    }

    let cursor = 0

    for (const m of matches) {
      const before = trimmed.slice(cursor, m.index)

      if (before) {
        lines.push(['', before])
      }

      lines.push([m[1]!, m[2]!])
      cursor = m.index! + m[0].length
    }

    if (cursor < trimmed.length) {
      lines.push(['', trimmed.slice(cursor)])
    }
  }

  return lines
}

// PULSAR wordmark — bloc ANSI Shadow, identité du CHU de Guyane.
const LOGO_ART = [
  '██████╗ ██╗   ██╗██╗     ███████╗ █████╗ ██████╗ ',
  '██╔══██╗██║   ██║██║     ██╔════╝██╔══██╗██╔══██╗',
  '██████╔╝██║   ██║██║     ███████╗███████║██████╔╝',
  '██╔═══╝ ██║   ██║██║     ╚════██║██╔══██║██╔══██╗',
  '██║     ╚██████╔╝███████╗███████║██║  ██║██║  ██║',
  '╚═╝      ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝'
]

// Hero radar-pulsar (anneaux concentriques + croisillon + croix médicale),
// remplace la caducée. Une pulsation balaie le champ : des agents veillent.
const CADUCEUS_ART = [
  '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀',
  '⠀⠀⠀⠀⠀⠀⠀⣀⠤⠒⠊⠉⠉⠉⠍⠉⠉⠑⠒⠤⣀⠀⠀⠀⠀⠀⠀⠀',
  '⠀⠀⠀⠀⢀⠴⠉⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠈⠑⢢⡀⠀⠀⠀⠀',
  '⠀⠀⠀⡰⠉⠀⠀⠀⢀⠤⠒⠉⠉⠉⠍⠉⠉⠒⠤⡀⠀⠀⠀⠘⢤⠀⠀⠀',
  '⠀⠀⡞⠀⠀⠀⢀⠖⠁⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⠈⠣⡄⠀⠀⠀⢣⠀⠀',
  '⠀⡸⠀⠀⠀⢰⠁⠀⠀⠀⡠⠒⠉⠍⠍⠍⠒⢄⠀⠀⠀⠘⡄⠀⠀⠀⢇⠀',
  '⠀⡇⠀⠀⠀⡇⠀⠀⠀⡜⠀⠀⠀⠅⠅⠅⠀⠀⢣⠀⠀⠀⢸⠀⠀⠀⢸⠀',
  '⠄⡇⠄⠄⠀⡇⠄⠀⠄⡅⠅⠅⠅⠅⠅⠅⠅⠅⢌⠄⠄⠄⢈⠄⠄⠀⢌⠄',
  '⠀⡇⠀⠀⠀⡇⠀⠀⠀⢣⠁⠁⠁⠅⠅⠅⠁⠁⡜⠀⠀⠀⢸⠀⠀⠀⢸⠀',
  '⠀⢱⠀⠀⠀⠸⡀⠀⠀⠀⠑⠤⣀⣁⣅⣁⠤⠊⠀⠀⠀⢠⠃⠀⠀⠀⡎⠀',
  '⠀⠀⢧⠀⠀⠀⠈⠦⡀⠀⠀⠀⠀⠀⠄⠀⠀⠀⠀⢀⡔⠃⠀⠀⠀⡜⠀⠀',
  '⠀⠀⠀⠱⣀⠀⠀⠀⠈⠒⠤⣀⣀⣀⣁⣀⣀⠤⠒⠁⠀⠀⠀⢠⠚⠀⠀⠀',
  '⠀⠀⠀⠀⠈⠲⣀⠀⠀⠀⠀⠀⠀⠀⠅⠀⠀⠀⠀⠀⢀⡠⠜⠁⠀⠀⠀⠀',
  '⠀⠀⠀⠀⠀⠀⠀⠉⠒⠤⢄⣀⣀⣀⣄⣀⣀⡠⠤⠒⠉⠀⠀⠀⠀⠀⠀⠀',
  '⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀'
]

const LOGO_GRADIENT = [0, 0, 1, 1, 2, 2] as const
const CADUC_GRADIENT = [3, 2, 2, 1, 1, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3] as const

const colorize = (art: string[], gradient: readonly number[], c: ThemeColors): Line[] => {
  const p = [c.primary, c.accent, c.border, c.muted]

  return art.map((text, i) => [p[gradient[i]!] ?? c.muted, text])
}

export const LOGO_WIDTH = Math.max(...LOGO_ART.map(line => line.length))
export const CADUCEUS_WIDTH = Math.max(...CADUCEUS_ART.map(line => line.length))

export const logo = (c: ThemeColors, customLogo?: string): Line[] =>
  customLogo ? parseRichMarkup(customLogo) : colorize(LOGO_ART, LOGO_GRADIENT, c)

export const caduceus = (c: ThemeColors, customHero?: string): Line[] =>
  customHero ? parseRichMarkup(customHero) : colorize(CADUCEUS_ART, CADUC_GRADIENT, c)

export const artWidth = (lines: Line[]) => lines.reduce((m, [, t]) => Math.max(m, t.length), 0)

type Line = [string, string]

// ── Hero radar-pulsar (croix médicale ROUGE constante) ───────────────
//
// Le hero de la caducée ne pouvait porter qu'une couleur par ligne. Le radar
// PULSAR a besoin d'une croix rouge AU MILIEU d'anneaux teintés par le thème,
// sur les mêmes lignes → on le rend en segments colorés (voir SegArtLines).
// '·' anneaux/croisillon (dim), '•' pulse (accent), '█' croix (rouge médical).
const MED_RED = '#EF5350'

const RADAR_ART = [
  '             ········',
  '         ····   ·    ···',
  '      ···    •••••••    ··',
  '     ··   •••   ·   •••   ··',
  '     ·   ••     ·     ••   ··',
  '    ·   ••      █      ••   ·',
  '    ····•·····█████·····•····',
  '    ·   ••      █      ••   ·',
  '     ·   ••     ·     ••   ··',
  '     ··   •••   ·   •••   ··',
  '      ···    •••••••    ··',
  '         ····   ·    ···',
  '             ········'
]

export type Seg = { c: string; b: boolean; t: string }

export const RADAR_WIDTH = Math.max(...RADAR_ART.map(line => line.length))

// Convertit chaque ligne du radar en segments colorés selon le thème, en
// fusionnant les caractères consécutifs de même style. La croix reste rouge.
export const radarHero = (c: ThemeColors): Seg[][] =>
  RADAR_ART.map(line => {
    const segs: Seg[] = []

    for (const ch of line) {
      const color = ch === '·' ? c.muted : ch === '•' ? c.accent : ch === '█' ? MED_RED : ''
      const bold = ch === '•' || ch === '█'
      const last = segs[segs.length - 1]

      if (last && last.c === color && last.b === bold) {
        last.t += ch
      } else {
        segs.push({ c: color, b: bold, t: ch })
      }
    }

    return segs
  })
