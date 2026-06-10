/**
 * HERMES CHU — Panneau de configuration des fournisseurs de modèles
 *
 * Ce composant étend la page Settings de hermes-agent (NousResearch) avec :
 *   - Azure OpenAI (fournisseur recommandé CHU, HDS)
 *   - ChatGPT via abonnement (flux device_code natif hermes-agent)
 *     → L'utilisateur voit un code OTP, se rend sur chatgpt.com/link,
 *       le saisit, et HERMES CHU se connecte automatiquement.
 *       Fonctionne avec les abonnements Plus, Team et Enterprise.
 *   - Nous Portal (Hermes natif, même flux device_code)
 *   - Ollama / vLLM / LM Studio (auto-hébergé, souverain)
 *   - Tous les providers hermes-agent natifs (OpenAI API, OpenRouter, Gemini…)
 *   - Indicateur Privacy Engine RGPD par fournisseur
 *
 * INTÉGRATION : Ce composant remplace providers-settings.tsx dans
 * upstream/hermes-desktop/apps/desktop/src/app/settings/providers-settings.tsx
 * via le système de patch CHU (chu-desktop/build-chu-desktop.sh).
 *
 * Le flux ChatGPT device_code est géré par hermes-agent natif :
 *   - backend : agent/auxiliary_client.py (openai-codex provider)
 *   - store   : apps/desktop/src/store/onboarding.ts
 *   - UI      : apps/desktop/src/components/desktop-onboarding-overlay.tsx
 * Ce composant ajoute le point d'entrée CHU et les informations hospitalières.
 */

import React, { useState } from 'react'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ProviderAuthType =
  | 'api_key'
  | 'oauth_device_code'   // ChatGPT abonnement, Nous Portal → chatgpt.com/link
  | 'oauth_external'      // xAI OAuth, Qwen, Gemini CLI, Anthropic PKCE
  | 'external_process'    // GitHub Copilot ACP (commande CLI)
  | 'none'                // Ollama, LM Studio (local sans auth)

interface ProviderDefinition {
  id: string
  name: string
  description: string
  authType: ProviderAuthType
  envKey?: string
  baseUrlEnvKey?: string
  recommended?: boolean
  sovereign?: boolean
  hdsCompatible?: boolean
  privacyRequired?: boolean
  privacyRecommended?: boolean
  subscriptionNote?: string
  docsUrl?: string
  badge?: string
  badgeColor?: string
}

// ---------------------------------------------------------------------------
// Catalogue des fournisseurs CHU
// ---------------------------------------------------------------------------

const CHU_PROVIDERS: ProviderDefinition[] = [
  // Recommandé CHU
  {
    id: 'azure-openai',
    name: 'Azure OpenAI',
    description: 'Hébergement souverain des modèles OpenAI sur Azure France. Recommandé pour les établissements de santé (HDS, RGPD).',
    authType: 'api_key',
    envKey: 'AZURE_OPENAI_API_KEY',
    baseUrlEnvKey: 'AZURE_OPENAI_ENDPOINT',
    recommended: true,
    hdsCompatible: true,
    privacyRecommended: true,
    badge: '☁️ HDS',
    badgeColor: 'bg-emerald-900 text-emerald-300',
    docsUrl: 'https://learn.microsoft.com/fr-fr/azure/ai-services/openai/',
  },

  // Souverains
  {
    id: 'vllm',
    name: 'vLLM (auto-hébergé)',
    description: 'Endpoint vLLM auto-hébergé sur votre infrastructure. Compatible Hermes-3, Mistral, LLaMA 3. Données souveraines.',
    authType: 'api_key',
    envKey: 'VLLM_API_KEY',
    baseUrlEnvKey: 'VLLM_BASE_URL',
    sovereign: true,
    hdsCompatible: true,
    badge: '🏥 Souverain',
    badgeColor: 'bg-blue-900 text-blue-300',
  },
  {
    id: 'ollama',
    name: 'Ollama (local)',
    description: 'Modèles exécutés localement via Ollama. Aucune donnée ne quitte votre poste. Mode souverain total.',
    authType: 'none',
    baseUrlEnvKey: 'OLLAMA_BASE_URL',
    sovereign: true,
    hdsCompatible: true,
    badge: '💻 Local',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://ollama.com',
  },
  {
    id: 'lmstudio',
    name: 'LM Studio (local)',
    description: 'Interface graphique pour exécuter des modèles localement. Compatible OpenAI API.',
    authType: 'none',
    baseUrlEnvKey: 'LM_BASE_URL',
    sovereign: true,
    hdsCompatible: true,
    badge: '💻 Local',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://lmstudio.ai',
  },

  // Abonnements (OAuth device_code)
  {
    id: 'openai-codex',
    name: 'ChatGPT (abonnement)',
    description: 'Connexion via votre abonnement ChatGPT Plus, Team ou Enterprise. Aucune clé API requise. Un code d\'appairage s\'affiche — saisissez-le sur chatgpt.com/link.',
    authType: 'oauth_device_code',
    privacyRequired: true,
    subscriptionNote: 'Requiert un abonnement ChatGPT actif (Plus, Team ou Enterprise)',
    badge: '💬 ChatGPT',
    badgeColor: 'bg-green-900 text-green-300',
    docsUrl: 'https://chatgpt.com',
  },
  {
    id: 'nous',
    name: 'Nous Portal (Hermes natif)',
    description: 'Accès aux modèles Hermes via le portail NousResearch. Authentification OAuth device_code.',
    authType: 'oauth_device_code',
    badge: '🤖 Hermes',
    badgeColor: 'bg-purple-900 text-purple-300',
    docsUrl: 'https://nousresearch.com',
  },

  // API Key (cloud)
  {
    id: 'openai-api',
    name: 'OpenAI API',
    description: 'Accès direct aux modèles GPT via clé API. Données traitées hors UE par OpenAI.',
    authType: 'api_key',
    envKey: 'OPENAI_API_KEY',
    baseUrlEnvKey: 'OPENAI_BASE_URL',
    privacyRequired: true,
    badge: '🔑 API',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://platform.openai.com/api-keys',
  },
  {
    id: 'openrouter',
    name: 'OpenRouter',
    description: 'Accès à 300+ modèles via une seule clé. Agrégateur multi-fournisseurs.',
    authType: 'api_key',
    envKey: 'OPENROUTER_API_KEY',
    privacyRecommended: true,
    badge: '🔑 API',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://openrouter.ai/keys',
  },
  {
    id: 'anthropic',
    name: 'Anthropic Claude',
    description: 'Modèles Claude Opus, Sonnet, Haiku via clé API ou OAuth PKCE.',
    authType: 'api_key',
    envKey: 'ANTHROPIC_API_KEY',
    privacyRequired: true,
    badge: '🔑 API',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://console.anthropic.com',
  },
  {
    id: 'gemini',
    name: 'Google Gemini',
    description: 'Modèles Gemini 2.5 Pro/Flash via clé API Google AI Studio.',
    authType: 'api_key',
    envKey: 'GEMINI_API_KEY',
    privacyRequired: true,
    badge: '🔑 API',
    badgeColor: 'bg-slate-700 text-slate-300',
    docsUrl: 'https://aistudio.google.com/app/apikey',
  },
  {
    id: 'xai-oauth',
    name: 'xAI Grok (OAuth)',
    description: 'Modèles Grok via abonnement SuperGrok ou Premium+. Authentification OAuth.',
    authType: 'oauth_external',
    privacyRequired: true,
    badge: '🔑 OAuth',
    badgeColor: 'bg-slate-700 text-slate-300',
  },
  {
    id: 'copilot',
    name: 'GitHub Copilot',
    description: 'Accès aux modèles via votre abonnement GitHub Copilot.',
    authType: 'api_key',
    envKey: 'GH_TOKEN',
    badge: '🔑 Token',
    badgeColor: 'bg-slate-700 text-slate-300',
  },
  {
    id: 'custom',
    name: 'Endpoint personnalisé',
    description: 'Tout endpoint compatible OpenAI (URL de base + clé API optionnelle).',
    authType: 'api_key',
    baseUrlEnvKey: 'OPENAI_BASE_URL',
    badge: '⚙️ Custom',
    badgeColor: 'bg-slate-700 text-slate-300',
  },
]

// ---------------------------------------------------------------------------
// Composant principal
// ---------------------------------------------------------------------------

export function ProvidersSettingsCHU() {
  const [selectedProviderId, setSelectedProviderId] = useState<string | null>(null)
  const [apiKey, setApiKey] = useState('')
  const [baseUrl, setBaseUrl] = useState('')
  const [deploymentName, setDeploymentName] = useState('')
  const [testStatus, setTestStatus] = useState<'idle' | 'testing' | 'ok' | 'error'>('idle')
  const [showAllProviders, setShowAllProviders] = useState(false)

  const recommended = CHU_PROVIDERS.filter((p) => p.recommended || p.sovereign)
  const others = CHU_PROVIDERS.filter((p) => !p.recommended && !p.sovereign)
  const displayedOthers = showAllProviders ? others : others.slice(0, 4)
  const selected = CHU_PROVIDERS.find((p) => p.id === selectedProviderId)

  const handleTestConnection = async () => {
    setTestStatus('testing')
    try {
      const res = await fetch('/api/chu/providers/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: selectedProviderId,
          api_key: apiKey,
          base_url: baseUrl,
          deployment: deploymentName,
        }),
      })
      const data = await res.json()
      setTestStatus(data.ok ? 'ok' : 'error')
    } catch {
      setTestStatus('error')
    }
  }

  const handleSaveProvider = async () => {
    if (!selectedProviderId) return
    await fetch('/api/chu/providers/configure', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider: selectedProviderId,
        api_key: apiKey,
        base_url: baseUrl,
        deployment: deploymentName,
      }),
    })
    // Notification IPC Electron
    if (typeof window !== 'undefined' && (window as any).hermeschu?.saveConfig) {
      await (window as any).hermeschu.saveConfig({
        provider: selectedProviderId,
        apiKey,
        baseUrl,
        deploymentName,
      })
    }
  }

  // Pour les providers OAuth, on délègue au système d'onboarding natif hermes-agent.
  // Pour openai-codex : déclenche le flux device_code → chatgpt.com/link
  const handleOAuthConnect = async (providerId: string) => {
    if (typeof window !== 'undefined' && (window as any).hermeschu?.startOAuth) {
      await (window as any).hermeschu.startOAuth(providerId)
    } else {
      await fetch('/api/chu/providers/oauth/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider: providerId }),
      })
    }
  }

  return (
    <div className="space-y-6 p-4 text-white">
      {/* En-tête */}
      <div>
        <h2 className="text-lg font-semibold">Fournisseurs de modèles</h2>
        <p className="text-sm text-slate-400 mt-1">
          Configurez vos fournisseurs d'IA. Le Privacy Engine RGPD s'applique à tous les flux.
        </p>
      </div>

      {/* Fournisseurs recommandés CHU */}
      <section>
        <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
          Recommandés CHU
        </h3>
        <div className="grid gap-3">
          {recommended.map((provider) => (
            <ProviderCard
              key={provider.id}
              provider={provider}
              isSelected={selectedProviderId === provider.id}
              onSelect={() => setSelectedProviderId(provider.id)}
              onOAuthConnect={handleOAuthConnect}
            />
          ))}
        </div>
      </section>

      {/* Autres fournisseurs */}
      <section>
        <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
          Autres fournisseurs
        </h3>
        <div className="grid gap-3">
          {displayedOthers.map((provider) => (
            <ProviderCard
              key={provider.id}
              provider={provider}
              isSelected={selectedProviderId === provider.id}
              onSelect={() => setSelectedProviderId(provider.id)}
              onOAuthConnect={handleOAuthConnect}
            />
          ))}
        </div>
        {others.length > 4 && (
          <button
            onClick={() => setShowAllProviders(!showAllProviders)}
            className="mt-3 text-xs text-blue-400 hover:text-blue-300 transition-colors"
          >
            {showAllProviders
              ? 'Réduire'
              : `Afficher ${others.length - 4} autres fournisseurs`}
          </button>
        )}
      </section>

      {/* Panneau de configuration du fournisseur sélectionné (API Key) */}
      {selected && selected.authType === 'api_key' && (
        <section className="rounded-lg border border-slate-700 bg-slate-800/50 p-4 space-y-4">
          <h3 className="text-sm font-semibold">Configuration — {selected.name}</h3>

          {selected.privacyRequired && (
            <div className="rounded-md bg-amber-900/30 border border-amber-700 p-3 text-xs text-amber-300">
              ⚠️ Ce fournisseur traite des données hors UE. Le Privacy Engine RGPD doit être
              actif pour tout usage avec des données de santé.
            </div>
          )}
          {selected.hdsCompatible && (
            <div className="rounded-md bg-emerald-900/30 border border-emerald-700 p-3 text-xs text-emerald-300">
              ✅ Compatible hébergement de données de santé (HDS) avec Privacy Engine actif.
            </div>
          )}

          {/* Endpoint Azure */}
          {selected.id === 'azure-openai' && (
            <div className="space-y-3">
              <div>
                <label className="block text-xs text-slate-400 mb-1">Endpoint Azure OpenAI</label>
                <input
                  type="url"
                  value={baseUrl}
                  onChange={(e) => setBaseUrl(e.target.value)}
                  placeholder="https://votre-ressource.openai.azure.com"
                  className="w-full rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block text-xs text-slate-400 mb-1">Nom du déploiement</label>
                <input
                  type="text"
                  value={deploymentName}
                  onChange={(e) => setDeploymentName(e.target.value)}
                  placeholder="gpt-4o, gpt-4-turbo…"
                  className="w-full rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
                />
              </div>
            </div>
          )}

          {/* URL de base pour vLLM / custom */}
          {(selected.id === 'vllm' || selected.id === 'custom') && (
            <div>
              <label className="block text-xs text-slate-400 mb-1">
                URL de base (endpoint OpenAI-compatible)
              </label>
              <input
                type="url"
                value={baseUrl}
                onChange={(e) => setBaseUrl(e.target.value)}
                placeholder={selected.id === 'vllm' ? 'http://vllm-service:8000/v1' : 'http://127.0.0.1:8000/v1'}
                className="w-full rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
              />
            </div>
          )}

          {/* URL Ollama */}
          {selected.id === 'ollama' && (
            <div>
              <label className="block text-xs text-slate-400 mb-1">URL Ollama</label>
              <input
                type="url"
                value={baseUrl}
                onChange={(e) => setBaseUrl(e.target.value)}
                placeholder="http://127.0.0.1:11434"
                className="w-full rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
              />
            </div>
          )}

          {/* Clé API */}
          {selected.authType === 'api_key' && selected.id !== 'ollama' && selected.id !== 'lmstudio' && (
            <div>
              <label className="block text-xs text-slate-400 mb-1">
                Clé API
                {selected.envKey && (
                  <span className="ml-2 font-mono text-slate-500">({selected.envKey})</span>
                )}
              </label>
              <input
                type="password"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
                placeholder="Collez votre clé API ici"
                className="w-full rounded-md bg-slate-900 border border-slate-600 px-3 py-2 text-sm text-white placeholder-slate-500 focus:border-blue-500 focus:outline-none"
              />
            </div>
          )}

          {/* Actions */}
          <div className="flex gap-2 pt-2 flex-wrap">
            <button
              onClick={handleTestConnection}
              disabled={testStatus === 'testing'}
              className="rounded-md bg-slate-700 hover:bg-slate-600 px-3 py-2 text-xs text-white transition-colors disabled:opacity-50"
            >
              {testStatus === 'testing' ? 'Test en cours…'
                : testStatus === 'ok' ? '✅ Connexion OK'
                : testStatus === 'error' ? '❌ Échec'
                : 'Tester la connexion'}
            </button>
            <button
              onClick={handleSaveProvider}
              className="rounded-md bg-blue-600 hover:bg-blue-500 px-3 py-2 text-xs text-white transition-colors"
            >
              Enregistrer
            </button>
            {selected.docsUrl && (
              <a
                href={selected.docsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="rounded-md border border-slate-600 hover:border-slate-500 px-3 py-2 text-xs text-slate-400 hover:text-white transition-colors"
              >
                Documentation ↗
              </a>
            )}
          </div>
        </section>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Carte fournisseur
// ---------------------------------------------------------------------------

interface ProviderCardProps {
  provider: ProviderDefinition
  isSelected: boolean
  onSelect: () => void
  onOAuthConnect: (providerId: string) => void
}

function ProviderCard({ provider, isSelected, onSelect, onOAuthConnect }: ProviderCardProps) {
  const isOAuth =
    provider.authType === 'oauth_device_code' ||
    provider.authType === 'oauth_external' ||
    provider.authType === 'external_process'

  return (
    <div
      className={`rounded-lg border p-4 transition-all ${
        isSelected
          ? 'border-blue-500 bg-blue-950/30'
          : 'border-slate-700 bg-slate-800/30 hover:border-slate-600'
      } ${!isOAuth ? 'cursor-pointer' : ''}`}
      onClick={!isOAuth ? onSelect : undefined}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap">
            <span className="text-sm font-medium text-white">{provider.name}</span>
            {provider.badge && (
              <span className={`text-xs rounded-full px-2 py-0.5 ${provider.badgeColor ?? 'bg-slate-700 text-slate-300'}`}>
                {provider.badge}
              </span>
            )}
            {provider.recommended && (
              <span className="text-xs rounded-full bg-emerald-800 px-2 py-0.5 text-emerald-300">
                Recommandé CHU
              </span>
            )}
            {provider.sovereign && (
              <span className="text-xs rounded-full bg-blue-900 px-2 py-0.5 text-blue-300">
                Souverain
              </span>
            )}
          </div>
          <p className="text-xs text-slate-400 mt-1 leading-relaxed">{provider.description}</p>

          {provider.subscriptionNote && (
            <p className="text-xs text-amber-400 mt-1">⚠️ {provider.subscriptionNote}</p>
          )}
          {provider.privacyRequired && (
            <p className="text-xs text-red-400 mt-1">
              🔒 Privacy Engine RGPD obligatoire pour les données de santé
            </p>
          )}
        </div>

        {/* Bouton d'action */}
        <div className="flex-shrink-0">
          {isOAuth ? (
            <button
              onClick={(e) => { e.stopPropagation(); onOAuthConnect(provider.id) }}
              className="rounded-md bg-blue-600 hover:bg-blue-500 px-3 py-1.5 text-xs text-white transition-colors whitespace-nowrap"
            >
              {provider.authType === 'oauth_device_code' ? 'Se connecter →'
                : provider.authType === 'external_process' ? 'Ouvrir terminal →'
                : 'Autoriser →'}
            </button>
          ) : provider.authType === 'none' ? (
            <button
              onClick={(e) => { e.stopPropagation(); onSelect() }}
              className="rounded-md border border-slate-600 hover:border-slate-500 px-3 py-1.5 text-xs text-slate-300 hover:text-white transition-colors"
            >
              Configurer
            </button>
          ) : (
            <button
              onClick={(e) => { e.stopPropagation(); onSelect() }}
              className={`rounded-md px-3 py-1.5 text-xs transition-colors ${
                isSelected
                  ? 'bg-blue-600 text-white'
                  : 'border border-slate-600 hover:border-slate-500 text-slate-300 hover:text-white'
              }`}
            >
              {isSelected ? 'Sélectionné ✓' : 'Configurer'}
            </button>
          )}
        </div>
      </div>

      {/* Explication détaillée du flux ChatGPT device_code */}
      {provider.id === 'openai-codex' && (
        <div className="mt-3 rounded-md bg-slate-900/50 border border-slate-700 p-3">
          <p className="text-xs text-slate-400 font-medium mb-2">
            Comment fonctionne la connexion par abonnement :
          </p>
          <ol className="text-xs text-slate-500 space-y-1 list-decimal list-inside">
            <li>Cliquez sur "Se connecter" — la page chatgpt.com/link s'ouvre dans votre navigateur</li>
            <li>Connectez-vous à votre compte ChatGPT (Plus, Team ou Enterprise)</li>
            <li>Un code d'appairage s'affiche dans HERMES CHU (ex: ABCD-1234)</li>
            <li>Saisissez ce code sur chatgpt.com/link</li>
            <li>HERMES CHU se connecte automatiquement — rien d'autre à faire</li>
          </ol>
          <div className="mt-2 flex gap-3">
            <p className="text-xs text-emerald-400">✅ Aucune clé API requise</p>
            <p className="text-xs text-emerald-400">✅ Accès à GPT-4o, o1, o3</p>
          </div>
        </div>
      )}

      {/* Explication flux Nous Portal device_code */}
      {provider.id === 'nous' && (
        <div className="mt-3 rounded-md bg-slate-900/50 border border-slate-700 p-3">
          <p className="text-xs text-slate-500">
            Accès aux modèles Hermes-3 (70B, 8B) via votre compte NousResearch.
            Même flux que ChatGPT : un code s'affiche, vous l'entrez sur le portail Nous.
          </p>
        </div>
      )}
    </div>
  )
}
