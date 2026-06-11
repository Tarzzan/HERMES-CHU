/**
 * HERMES CHU Desktop — Preload Script
 * =====================================
 * Expose les APIs CHU au renderer via contextBridge de manière sécurisée.
 * Intégration : merger avec electron/preload.cjs de hermes-desktop.
 *
 * Usage dans le renderer :
 *   window.hermeschu.privacy.status()
 *   window.hermeschu.privacy.toggle(true)
 *   window.hermeschu.privacy.glassBreak({ justification, duree_minutes })
 *   window.hermeschu.config.get()
 *   window.hermeschu.config.save({ fournisseur_actif, parametres })
 *   window.hermeschu.audit.journal({ limite, type_evenement })
 *   window.hermeschu.metrics.usage()
 *   window.hermeschu.metrics.anonymisation()
 *   window.hermeschu.metrics.insights()
 *   window.hermeschu.health()
 */

'use strict'

const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('hermeschu', {
  privacy: {
    status: () => ipcRenderer.invoke('chu:privacy:status'),
    toggle: (actif) => ipcRenderer.invoke('chu:privacy:toggle', actif),
    glassBreak: (args) => ipcRenderer.invoke('chu:privacy:glass-break', args),
  },
  config: {
    get: () => ipcRenderer.invoke('chu:config:get'),
    save: (config) => ipcRenderer.invoke('chu:config:save', config),
  },
  audit: {
    journal: (opts) => ipcRenderer.invoke('chu:audit:journal', opts),
  },
  metrics: {
    usage: () => ipcRenderer.invoke('chu:metriques'),
    anonymisation: () => ipcRenderer.invoke('chu:anonymisation:stats'),
    insights: () => ipcRenderer.invoke('chu:insights'),
  },
  health: () => ipcRenderer.invoke('chu:health'),
  version: '1.0.0',
})
