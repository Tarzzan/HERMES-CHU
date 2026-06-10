import { useState, useRef, useEffect, KeyboardEvent } from 'react'
import { useAuth } from '../contexts/AuthContext'

interface Message {
  id: string
  role: 'user' | 'assistant' | 'systeme'
  contenu: string
  horodatage: Date
  nbIterations?: number
  avertissement?: string
}

const MESSAGES_INITIAUX: Message[] = [
  {
    id: 'init',
    role: 'systeme',
    contenu: 'Bienvenue sur HERMES CHU. Je suis votre Agent Pilote. Comment puis-je vous aider aujourd\'hui ?\n\nToutes vos données sont anonymisées avant traitement. Les interactions sont journalisées conformément à la politique ISO 27001 du CHU.',
    horodatage: new Date(),
  }
]

const SUGGESTIONS = [
  'Génère une synthèse médicale pour le dossier en cours',
  'Quels sont les lits disponibles en cardiologie ?',
  'Recherche les dernières recommandations HAS sur l\'HTA',
  'Aide-moi à rédiger une lettre de sortie',
  'Vérifie les interactions médicamenteuses de cette ordonnance',
]

export default function DialoguePage() {
  const { utilisateur } = useAuth()
  const [messages, setMessages] = useState<Message[]>(MESSAGES_INITIAUX)
  const [saisie, setSaisie] = useState('')
  const [enChargement, setEnChargement] = useState(false)
  const [idSession, setIdSession] = useState<string | null>(null)
  const [anonymisationActive, setAnonymisationActive] = useState(true)
  const [afficherSuggestions, setAfficherSuggestions] = useState(true)
  const finListeRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    finListeRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const envoyerMessage = async (texte?: string) => {
    const contenu = texte || saisie.trim()
    if (!contenu || enChargement) return

    setAfficherSuggestions(false)
    setSaisie('')
    setEnChargement(true)

    const msgUtilisateur: Message = {
      id: Date.now().toString(),
      role: 'user',
      contenu,
      horodatage: new Date(),
    }
    setMessages(prev => [...prev, msgUtilisateur])

    try {
      // Appel à l'API de l'orchestrateur (SSE streaming)
      const reponse = await fetch('/api/v1/chat/stream', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${utilisateur?.token}`,
        },
        body: JSON.stringify({
          id_session: idSession,
          message: contenu,
          id_utilisateur: utilisateur?.id || 'demo',
          role_utilisateur: utilisateur?.role || 'ROLE_CLINICIEN',
          service: utilisateur?.service || '',
          anonymisation_active: anonymisationActive,
        }),
      })

      if (!reponse.ok) throw new Error(`Erreur HTTP ${reponse.status}`)

      const reader = reponse.body?.getReader()
      const decoder = new TextDecoder()
      let contenuAssistant = ''
      let idSessionRecu: string | null = null

      const msgAssistant: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        contenu: '',
        horodatage: new Date(),
      }
      setMessages(prev => [...prev, msgAssistant])

      while (reader) {
        const { done, value } = await reader.read()
        if (done) break

        const texte = decoder.decode(value)
        const lignes = texte.split('\n')

        for (const ligne of lignes) {
          if (!ligne.startsWith('data: ')) continue
          const donnees = ligne.slice(6)
          if (donnees === '[DONE]') break

          try {
            const json = JSON.parse(donnees)
            if (json.id_session) {
              idSessionRecu = json.id_session
              setIdSession(json.id_session)
            }
            if (json.fragment) {
              contenuAssistant += json.fragment.replace(/\\n/g, '\n')
              setMessages(prev =>
                prev.map(m =>
                  m.id === msgAssistant.id
                    ? { ...m, contenu: contenuAssistant }
                    : m
                )
              )
            }
          } catch {}
        }
      }
    } catch (err: any) {
      // En mode démo (sans backend), simulation d'une réponse
      const reponsesDemo: Record<string, string> = {
        default: `Je suis l'Agent Pilote HERMES CHU. Votre demande a bien été reçue.\n\n**Mode démonstration** — Le backend n'est pas connecté dans cet environnement de prévisualisation.\n\nEn production, je traiterais votre demande en :\n1. Anonymisant vos données via le Privacy Engine\n2. Analysant votre requête\n3. Déléguant aux agents spécialisés appropriés\n4. Vous retournant une réponse structurée\n\n*Toutes les interactions sont journalisées conformément à ISO 27001.*`,
      }

      const reponseDemoMsg = reponsesDemo.default
      const msgDemo: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        contenu: reponseDemoMsg,
        horodatage: new Date(),
        avertissement: 'Mode démonstration — Backend non connecté',
      }
      setMessages(prev => [...prev, msgDemo])
    } finally {
      setEnChargement(false)
      textareaRef.current?.focus()
    }
  }

  const gererToucheClavier = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      envoyerMessage()
    }
  }

  const viderConversation = () => {
    setMessages(MESSAGES_INITIAUX)
    setIdSession(null)
    setAfficherSuggestions(true)
  }

  return (
    <div className="flex flex-col h-full bg-gray-950">
      {/* ── Barre d'outils ── */}
      <div className="flex items-center justify-between px-6 py-3 border-b border-gray-800 bg-gray-900">
        <div className="flex items-center gap-3">
          <h1 className="text-sm font-semibold text-white">Agent Pilote</h1>
          {idSession && (
            <span className="text-xs text-gray-500 font-mono">
              Session: {idSession.slice(0, 8)}…
            </span>
          )}
        </div>
        <div className="flex items-center gap-3">
          {/* Toggle anonymisation */}
          <label className="flex items-center gap-2 cursor-pointer">
            <span className="text-xs text-gray-400">Anonymisation</span>
            <div
              onClick={() => setAnonymisationActive(!anonymisationActive)}
              className={`relative w-10 h-5 rounded-full transition-colors cursor-pointer ${
                anonymisationActive ? 'bg-green-600' : 'bg-red-600'
              }`}
            >
              <div className={`absolute top-0.5 w-4 h-4 rounded-full bg-white transition-transform ${
                anonymisationActive ? 'translate-x-5' : 'translate-x-0.5'
              }`} />
            </div>
            <span className={`text-xs font-medium ${anonymisationActive ? 'text-green-400' : 'text-red-400'}`}>
              {anonymisationActive ? 'Active' : 'Désactivée'}
            </span>
          </label>
          <button
            onClick={viderConversation}
            className="text-xs text-gray-400 hover:text-white px-3 py-1.5 border border-gray-700 hover:border-gray-500 rounded-lg transition-colors"
          >
            Nouvelle conversation
          </button>
        </div>
      </div>

      {/* ── Zone de messages ── */}
      <div className="flex-1 overflow-y-auto px-6 py-6 space-y-6">
        {messages.map(msg => (
          <div key={msg.id} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            {msg.role === 'systeme' ? (
              <div className="max-w-2xl w-full bg-blue-950 border border-blue-800 rounded-xl px-5 py-4 text-sm text-blue-200">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-5 h-5 rounded-full bg-blue-600 flex items-center justify-center text-xs font-bold">H</span>
                  <span className="font-medium text-blue-300">HERMES CHU</span>
                </div>
                <p className="whitespace-pre-wrap leading-relaxed">{msg.contenu}</p>
              </div>
            ) : msg.role === 'user' ? (
              <div className="max-w-xl bg-blue-600 rounded-2xl rounded-tr-sm px-4 py-3 text-sm text-white">
                <p className="whitespace-pre-wrap">{msg.contenu}</p>
                <p className="text-xs text-blue-200 mt-1 text-right">
                  {msg.horodatage.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                </p>
              </div>
            ) : (
              <div className="max-w-2xl w-full">
                <div className="flex items-center gap-2 mb-2">
                  <span className="w-6 h-6 rounded-full bg-gray-700 flex items-center justify-center text-xs font-bold">H</span>
                  <span className="text-xs font-medium text-gray-400">Agent Pilote</span>
                  <span className="text-xs text-gray-600">
                    {msg.horodatage.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>
                <div className="bg-gray-900 border border-gray-800 rounded-2xl rounded-tl-sm px-5 py-4 text-sm text-gray-100">
                  {msg.contenu ? (
                    <div className="whitespace-pre-wrap leading-relaxed prose prose-invert prose-sm max-w-none">
                      {msg.contenu}
                    </div>
                  ) : (
                    <div className="flex items-center gap-2 text-gray-400">
                      <div className="flex gap-1">
                        <span className="w-2 h-2 rounded-full bg-blue-400 animate-bounce" style={{ animationDelay: '0ms' }} />
                        <span className="w-2 h-2 rounded-full bg-blue-400 animate-bounce" style={{ animationDelay: '150ms' }} />
                        <span className="w-2 h-2 rounded-full bg-blue-400 animate-bounce" style={{ animationDelay: '300ms' }} />
                      </div>
                      <span className="text-xs">Traitement en cours…</span>
                    </div>
                  )}
                  {msg.avertissement && (
                    <div className="mt-3 pt-3 border-t border-gray-700 text-xs text-amber-400 flex items-center gap-1">
                      <span>⚠️</span>
                      <span>{msg.avertissement}</span>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>
        ))}

        {/* Suggestions initiales */}
        {afficherSuggestions && messages.length <= 1 && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mt-4">
            {SUGGESTIONS.map((suggestion, i) => (
              <button
                key={i}
                onClick={() => envoyerMessage(suggestion)}
                className="text-left px-4 py-3 bg-gray-900 border border-gray-800 hover:border-blue-600 rounded-xl text-sm text-gray-300 hover:text-white transition-all"
              >
                {suggestion}
              </button>
            ))}
          </div>
        )}

        <div ref={finListeRef} />
      </div>

      {/* ── Zone de saisie ── */}
      <div className="px-6 py-4 border-t border-gray-800 bg-gray-900">
        {!anonymisationActive && (
          <div className="mb-3 px-4 py-2 bg-red-950 border border-red-800 rounded-lg text-xs text-red-300 flex items-center gap-2">
            <span>⚠️</span>
            <span>
              <strong>Attention</strong> — L'anonymisation est désactivée. Les données saisies seront traitées sans anonymisation préalable. Cette opération est journalisée.
            </span>
          </div>
        )}
        <div className="flex gap-3 items-end">
          <textarea
            ref={textareaRef}
            value={saisie}
            onChange={e => setSaisie(e.target.value)}
            onKeyDown={gererToucheClavier}
            placeholder="Posez votre question à l'Agent Pilote… (Entrée pour envoyer, Maj+Entrée pour un saut de ligne)"
            rows={3}
            disabled={enChargement}
            className="flex-1 bg-gray-800 border border-gray-700 focus:border-blue-500 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 resize-none outline-none transition-colors disabled:opacity-50"
          />
          <button
            onClick={() => envoyerMessage()}
            disabled={!saisie.trim() || enChargement}
            className="px-5 py-3 bg-blue-600 hover:bg-blue-500 disabled:bg-gray-700 disabled:text-gray-500 text-white rounded-xl font-medium text-sm transition-colors flex items-center gap-2"
          >
            {enChargement ? (
              <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <span>↑</span>
            )}
            Envoyer
          </button>
        </div>
        <p className="text-xs text-gray-600 mt-2 text-center">
          HERMES CHU — Aide à la décision médicale · Validation humaine obligatoire · ISO 27001 / HDS
        </p>
      </div>
    </div>
  )
}
