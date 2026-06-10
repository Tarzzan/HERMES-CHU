/**
 * HERMES CHU Desktop — Module IPC Electron
 * ==========================================
 * Gère la communication sécurisée entre le renderer React
 * et le backend Python (Privacy Engine + API CHU).
 *
 * Intégration : require('./chu-ipc.cjs') dans electron/main.cjs
 * juste après les autres requires.
 *
 * Canaux IPC exposés :
 *   chu:privacy:status      → GET /api/chu/privacy/statut
 *   chu:privacy:toggle      → POST /api/chu/privacy/toggle
 *   chu:privacy:glass-break → POST /api/chu/privacy/glass-break
 *   chu:config:get          → GET /api/chu/config
 *   chu:config:save         → POST /api/chu/config
 *   chu:audit:journal       → GET /api/chu/audit/journal
 *   chu:health              → GET /api/chu/sante
 */

'use strict'

const { ipcMain, Notification } = require('electron')
const https = require('node:https')
const http = require('node:http')

const CHU_API_BASE = process.env.CHU_API_BASE || 'http://localhost:8001'
const CHU_API_TIMEOUT_MS = 8_000

// ---------------------------------------------------------------------------
// Utilitaire de requête HTTP vers l'API CHU
// ---------------------------------------------------------------------------

function apiCHU(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(CHU_API_BASE + path)
    const isHttps = url.protocol === 'https:'
    const lib = isHttps ? https : http

    const options = {
      hostname: url.hostname,
      port: url.port || (isHttps ? 443 : 80),
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-CHU-Desktop': '1',
        'X-CHU-Version': '1.0.0',
      },
      timeout: CHU_API_TIMEOUT_MS,
    }

    const req = lib.request(options, (res) => {
      let data = ''
      res.on('data', chunk => { data += chunk })
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) })
        } catch {
          resolve({ status: res.statusCode, data })
        }
      })
    })

    req.on('error', reject)
    req.on('timeout', () => {
      req.destroy()
      reject(new Error('Timeout API CHU'))
    })

    if (body) req.write(JSON.stringify(body))
    req.end()
  })
}

// ---------------------------------------------------------------------------
// Enregistrement des handlers IPC
// ---------------------------------------------------------------------------

function registerCHUIpcHandlers() {

  // --- Privacy Engine ---

  ipcMain.handle('chu:privacy:status', async () => {
    try {
      const { data } = await apiCHU('GET', '/api/chu/privacy/statut')
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  ipcMain.handle('chu:privacy:toggle', async (_event, actif) => {
    try {
      const { data } = await apiCHU('POST', '/api/chu/privacy/toggle', { actif })
      // Notification système
      if (Notification.isSupported()) {
        new Notification({
          title: 'HERMES CHU — Privacy Engine',
          body: actif
            ? '🔒 Anonymisation RGPD activée'
            : '⚠️ Anonymisation désactivée — données brutes',
          urgency: actif ? 'normal' : 'critical',
        }).show()
      }
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  ipcMain.handle('chu:privacy:glass-break', async (_event, { justification, duree_minutes }) => {
    try {
      const { data, status } = await apiCHU('POST', '/api/chu/privacy/glass-break', {
        justification,
        duree_minutes,
      })
      if (status === 200) {
        if (Notification.isSupported()) {
          new Notification({
            title: '⚠️ HERMES CHU — Glass-Break activé',
            body: `Anonymisation suspendue ${duree_minutes} min. Journalisé dans l'audit ISO 27001.`,
            urgency: 'critical',
          }).show()
        }
        return { ok: true, data }
      }
      return { ok: false, error: data?.detail || 'Erreur Glass-Break' }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  // --- Configuration LLM ---

  ipcMain.handle('chu:config:get', async () => {
    try {
      const { data } = await apiCHU('GET', '/api/chu/config')
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  ipcMain.handle('chu:config:save', async (_event, config) => {
    try {
      const { data } = await apiCHU('POST', '/api/chu/config', config)
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  // --- Journal d'audit ISO 27001 ---

  ipcMain.handle('chu:audit:journal', async (_event, { limite = 50, type_evenement } = {}) => {
    try {
      const qs = new URLSearchParams({ limite: String(limite) })
      if (type_evenement) qs.set('type_evenement', type_evenement)
      const { data } = await apiCHU('GET', `/api/chu/audit/journal?${qs}`)
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  })

  // --- Healthcheck ---

  ipcMain.handle('chu:health', async () => {
    try {
      const { data } = await apiCHU('GET', '/api/chu/sante')
      return { ok: true, data }
    } catch (e) {
      return { ok: false, error: e.message, apiBase: CHU_API_BASE }
    }
  })

  console.log('[HERMES CHU] Handlers IPC enregistrés — API CHU :', CHU_API_BASE)
}

module.exports = { registerCHUIpcHandlers, apiCHU }
