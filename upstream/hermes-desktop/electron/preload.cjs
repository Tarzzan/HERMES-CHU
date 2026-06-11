const { contextBridge, ipcRenderer, webUtils } = require('electron')

contextBridge.exposeInMainWorld('pulsarDesktop', {
  getConnection: profile => ipcRenderer.invoke('pulsar:connection', profile),
  revalidateConnection: () => ipcRenderer.invoke('pulsar:connection:revalidate'),
  touchBackend: profile => ipcRenderer.invoke('pulsar:backend:touch', profile),
  getGatewayWsUrl: profile => ipcRenderer.invoke('pulsar:gateway:ws-url', profile),
  openSessionWindow: sessionId => ipcRenderer.invoke('pulsar:window:openSession', sessionId),
  getBootProgress: () => ipcRenderer.invoke('pulsar:boot-progress:get'),
  getConnectionConfig: profile => ipcRenderer.invoke('pulsar:connection-config:get', profile),
  saveConnectionConfig: payload => ipcRenderer.invoke('pulsar:connection-config:save', payload),
  applyConnectionConfig: payload => ipcRenderer.invoke('pulsar:connection-config:apply', payload),
  testConnectionConfig: payload => ipcRenderer.invoke('pulsar:connection-config:test', payload),
  probeConnectionConfig: remoteUrl => ipcRenderer.invoke('pulsar:connection-config:probe', remoteUrl),
  oauthLoginConnectionConfig: remoteUrl => ipcRenderer.invoke('pulsar:connection-config:oauth-login', remoteUrl),
  oauthLogoutConnectionConfig: remoteUrl => ipcRenderer.invoke('pulsar:connection-config:oauth-logout', remoteUrl),
  profile: {
    get: () => ipcRenderer.invoke('pulsar:profile:get'),
    set: name => ipcRenderer.invoke('pulsar:profile:set', name)
  },
  api: request => ipcRenderer.invoke('pulsar:api', request),
  notify: payload => ipcRenderer.invoke('pulsar:notify', payload),
  requestMicrophoneAccess: () => ipcRenderer.invoke('pulsar:requestMicrophoneAccess'),
  readFileDataUrl: filePath => ipcRenderer.invoke('pulsar:readFileDataUrl', filePath),
  readFileText: filePath => ipcRenderer.invoke('pulsar:readFileText', filePath),
  selectPaths: options => ipcRenderer.invoke('pulsar:selectPaths', options),
  writeClipboard: text => ipcRenderer.invoke('pulsar:writeClipboard', text),
  saveImageFromUrl: url => ipcRenderer.invoke('pulsar:saveImageFromUrl', url),
  saveImageBuffer: (data, ext) => ipcRenderer.invoke('pulsar:saveImageBuffer', { data, ext }),
  saveClipboardImage: () => ipcRenderer.invoke('pulsar:saveClipboardImage'),
  getPathForFile: file => {
    try {
      return webUtils.getPathForFile(file) || ''
    } catch {
      return ''
    }
  },
  normalizePreviewTarget: (target, baseDir) => ipcRenderer.invoke('pulsar:normalizePreviewTarget', target, baseDir),
  watchPreviewFile: url => ipcRenderer.invoke('pulsar:watchPreviewFile', url),
  stopPreviewFileWatch: id => ipcRenderer.invoke('pulsar:stopPreviewFileWatch', id),
  setTitleBarTheme: payload => ipcRenderer.send('pulsar:titlebar-theme', payload),
  setPreviewShortcutActive: active => ipcRenderer.send('pulsar:previewShortcutActive', Boolean(active)),
  openExternal: url => ipcRenderer.invoke('pulsar:openExternal', url),
  fetchLinkTitle: url => ipcRenderer.invoke('pulsar:fetchLinkTitle', url),
  sanitizeWorkspaceCwd: cwd => ipcRenderer.invoke('pulsar:workspace:sanitize', cwd),
  settings: {
    getDefaultProjectDir: () => ipcRenderer.invoke('pulsar:setting:defaultProjectDir:get'),
    setDefaultProjectDir: dir => ipcRenderer.invoke('pulsar:setting:defaultProjectDir:set', dir),
    pickDefaultProjectDir: () => ipcRenderer.invoke('pulsar:setting:defaultProjectDir:pick')
  },
  revealLogs: () => ipcRenderer.invoke('pulsar:logs:reveal'),
  getRecentLogs: () => ipcRenderer.invoke('pulsar:logs:recent'),
  readDir: dirPath => ipcRenderer.invoke('pulsar:fs:readDir', dirPath),
  gitRoot: startPath => ipcRenderer.invoke('pulsar:fs:gitRoot', startPath),
  terminal: {
    dispose: id => ipcRenderer.invoke('pulsar:terminal:dispose', id),
    resize: (id, size) => ipcRenderer.invoke('pulsar:terminal:resize', id, size),
    start: options => ipcRenderer.invoke('pulsar:terminal:start', options),
    write: (id, data) => ipcRenderer.invoke('pulsar:terminal:write', id, data),
    onData: (id, callback) => {
      const channel = `pulsar:terminal:${id}:data`
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on(channel, listener)
      return () => ipcRenderer.removeListener(channel, listener)
    },
    onExit: (id, callback) => {
      const channel = `pulsar:terminal:${id}:exit`
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on(channel, listener)
      return () => ipcRenderer.removeListener(channel, listener)
    }
  },
  onClosePreviewRequested: callback => {
    const listener = () => callback()
    ipcRenderer.on('pulsar:close-preview-requested', listener)
    return () => ipcRenderer.removeListener('pulsar:close-preview-requested', listener)
  },
  onOpenUpdatesRequested: callback => {
    const listener = () => callback()
    ipcRenderer.on('pulsar:open-updates', listener)
    return () => ipcRenderer.removeListener('pulsar:open-updates', listener)
  },
  onWindowStateChanged: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('pulsar:window-state-changed', listener)
    return () => ipcRenderer.removeListener('pulsar:window-state-changed', listener)
  },
  onPreviewFileChanged: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('pulsar:preview-file-changed', listener)
    return () => ipcRenderer.removeListener('pulsar:preview-file-changed', listener)
  },
  onBackendExit: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('pulsar:backend-exit', listener)
    return () => ipcRenderer.removeListener('pulsar:backend-exit', listener)
  },
  onPowerResume: callback => {
    const listener = () => callback()
    ipcRenderer.on('pulsar:power-resume', listener)
    return () => ipcRenderer.removeListener('pulsar:power-resume', listener)
  },
  onBootProgress: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('pulsar:boot-progress', listener)
    return () => ipcRenderer.removeListener('pulsar:boot-progress', listener)
  },
  // First-launch bootstrap progress -- emitted by the install.ps1 stage
  // runner in main.cjs (apps/desktop/electron/bootstrap-runner.cjs).
  // Renderer's install overlay subscribes to live events and queries the
  // current snapshot via getBootstrapState() to recover after a devtools
  // reload mid-bootstrap.
  getBootstrapState: () => ipcRenderer.invoke('pulsar:bootstrap:get'),
  resetBootstrap: () => ipcRenderer.invoke('pulsar:bootstrap:reset'),
  repairBootstrap: () => ipcRenderer.invoke('pulsar:bootstrap:repair'),
  cancelBootstrap: () => ipcRenderer.invoke('pulsar:bootstrap:cancel'),
  onBootstrapEvent: callback => {
    const listener = (_event, payload) => callback(payload)
    ipcRenderer.on('pulsar:bootstrap:event', listener)
    return () => ipcRenderer.removeListener('pulsar:bootstrap:event', listener)
  },
  getVersion: () => ipcRenderer.invoke('pulsar:version'),
  uninstall: {
    summary: () => ipcRenderer.invoke('pulsar:uninstall:summary'),
    run: mode => ipcRenderer.invoke('pulsar:uninstall:run', { mode })
  },
  updates: {
    check: () => ipcRenderer.invoke('pulsar:updates:check'),
    apply: opts => ipcRenderer.invoke('pulsar:updates:apply', opts),
    getBranch: () => ipcRenderer.invoke('pulsar:updates:branch:get'),
    setBranch: name => ipcRenderer.invoke('pulsar:updates:branch:set', name),
    onProgress: callback => {
      const listener = (_event, payload) => callback(payload)
      ipcRenderer.on('pulsar:updates:progress', listener)
      return () => ipcRenderer.removeListener('pulsar:updates:progress', listener)
    }
  },
  themes: {
    fetchMarketplace: id => ipcRenderer.invoke('pulsar:vscode-theme:fetch', id),
    searchMarketplace: query => ipcRenderer.invoke('pulsar:vscode-theme:search', query)
  }
})
