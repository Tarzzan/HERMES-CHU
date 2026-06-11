/**
 * PULSAR CHU — Traductions françaises complètes
 * Basé sur la structure i18n de hermes-agent (DSIO CHU de Guyane)
 * Adapté pour le contexte hospitalier CHU
 *
 * Couvre tous les flux d'authentification :
 *   - API Key (Azure OpenAI, OpenAI, OpenRouter, Gemini, xAI…)
 *   - OAuth Device Code (ChatGPT abonnement Plus/Team/Enterprise → chatgpt.com/link)
 *   - OAuth PKCE / loopback (Nous Portal, xAI OAuth, Anthropic OAuth…)
 *   - OAuth externe / CLI (GitHub Copilot, Gemini CLI, Qwen…)
 */
import type { Translations } from './types'

export const fr: Translations = {
  // ---------------------------------------------------------------------------
  // COMMUN
  // ---------------------------------------------------------------------------
  common: {
    apply: 'Appliquer',
    back: 'Retour',
    save: 'Enregistrer',
    saving: 'Enregistrement…',
    cancel: 'Annuler',
    change: 'Modifier',
    choose: 'Choisir',
    clear: 'Effacer',
    close: 'Fermer',
    collapse: 'Réduire',
    confirm: 'Confirmer',
    connect: 'Connecter',
    connecting: 'Connexion en cours',
    continue: 'Continuer',
    copied: 'Copié',
    copy: 'Copier',
    copyFailed: 'Échec de la copie',
    delete: 'Supprimer',
    docs: 'Documentation',
    done: 'Terminé',
    error: 'Erreur',
    failed: 'Échec',
    free: 'Gratuit',
    loading: 'Chargement…',
    notSet: 'Non défini',
    refresh: 'Actualiser',
    remove: 'Retirer',
    replace: 'Remplacer',
    retry: 'Réessayer',
    run: 'Exécuter',
    send: 'Envoyer',
    set: 'Définir',
    skip: 'Ignorer',
    update: 'Mettre à jour',
    on: 'Activé',
    off: 'Désactivé',
  },

  // ---------------------------------------------------------------------------
  // DÉMARRAGE
  // ---------------------------------------------------------------------------
  boot: {
    ready: 'PULSAR CHU est prêt',
    desktopBootFailedWithMessage: (message) => `Échec du démarrage : ${message}`,
    steps: {
      connectingGateway: 'Connexion à la passerelle hospitalière',
      loadingSettings: 'Chargement des paramètres CHU',
      loadingSessions: 'Chargement des sessions sécurisées',
      startingDesktopConnection: 'Démarrage de la connexion bureau',
      startingHermesDesktop: 'Démarrage de PULSAR CHU…',
    },
    errors: {
      backgroundExited: 'Le processus en arrière-plan s\'est arrêté.',
      backgroundExitedDuringStartup: 'Le processus s\'est arrêté pendant le démarrage.',
      backendStopped: 'Backend arrêté',
      desktopBootFailed: 'Échec du démarrage de l\'application',
      gatewaySignInRequired: 'Authentification requise',
      ipcBridgeUnavailable: 'Le pont IPC est indisponible.',
    },
    failure: {
      title: 'PULSAR CHU n\'a pas pu démarrer',
      description:
        'La passerelle sécurisée n\'a pas répondu. Essayez une des options de récupération ci-dessous. Vos données et paramètres sont conservés.',
      remoteTitle: 'Authentification distante requise',
      remoteDescription:
        'Votre session distante a expiré. Reconnectez-vous pour continuer.',
      retry: 'Réessayer',
      repairInstall: 'Réparer l\'installation',
      useLocalGateway: 'Utiliser la passerelle locale',
      openLogs: 'Ouvrir les journaux',
      repairHint: 'La réparation relance l\'installation (peut prendre quelques minutes).',
      remoteSignInHint:
        'Ouvre la fenêtre de connexion. Utilisez la passerelle locale pour basculer sur le backend intégré.',
      hideRecentLogs: 'Masquer les journaux',
      showRecentLogs: 'Afficher les journaux',
      signedInTitle: 'Connecté',
      signedInMessage: 'Reconnexion à la passerelle…',
      signInIncompleteTitle: 'Connexion incomplète',
      signInIncompleteMessage:
        'La fenêtre s\'est fermée avant la fin de l\'authentification.',
      signInFailed: 'Échec de la connexion',
      signInToRemoteGateway: 'Se connecter à la passerelle',
      signInWithProvider: (provider) => `Se connecter avec ${provider}`,
      identityProvider: 'votre fournisseur d\'identité',
    },
  },

  // ---------------------------------------------------------------------------
  // ONBOARDING — Connexion au fournisseur de modèle
  //
  // Flux supportés :
  //   api_key        → saisie d'une clé API (Azure OpenAI, OpenAI, Gemini…)
  //   oauth_device_code → code d'appairage affiché + saisie sur chatgpt.com/link
  //                       (ChatGPT Plus / Team / Enterprise, Nous Portal)
  //   oauth_external → navigateur ouvert + attente automatique
  //                    (xAI OAuth, Qwen, Gemini CLI, Anthropic PKCE…)
  //   external_process → commande CLI à exécuter dans un terminal
  //                       (GitHub Copilot ACP, Copilot CLI…)
  // ---------------------------------------------------------------------------
  onboarding: {
    headerTitle: 'Connectez PULSAR CHU à un modèle d\'IA',
    headerDesc:
      'Choisissez un fournisseur pour commencer. La plupart des options se configurent en un clic.',
    preparingInstall:
      'PULSAR CHU finalise l\'installation. Cela prend généralement moins d\'une minute au premier démarrage.',
    starting: 'Démarrage de PULSAR CHU…',
    lookingUpProviders: 'Recherche des fournisseurs disponibles…',
    collapse: 'Réduire',
    otherProviders: 'Autres fournisseurs',
    haveApiKey: 'J\'ai une clé API',
    chooseLater: 'Je choisirai un fournisseur plus tard',
    recommended: 'Recommandé',
    connected: 'Connecté',
    featuredPitch:
      'Un abonnement, plus de 300 modèles de pointe — la méthode recommandée pour PULSAR CHU',
    openRouterPitch: 'Une clé, des centaines de modèles — une valeur sûre',

    // Descriptions des fournisseurs dans le formulaire de clé API
    apiKeyOptions: {
      'azure-openai': {
        short: 'Azure OpenAI (CHU recommandé)',
        description:
          'Accès souverain aux modèles OpenAI hébergés sur Azure France. Recommandé pour les établissements de santé (HDS, RGPD). Nécessite un endpoint Azure et une clé API.',
      },
      openrouter: {
        short: 'une clé, de nombreux modèles',
        description:
          'Accès à des centaines de modèles via une seule clé. Bon choix par défaut pour les nouvelles installations.',
      },
      openai: {
        short: 'modèles GPT (clé API)',
        description:
          'Accès direct aux modèles OpenAI via clé API. Données traitées hors UE — activer le Privacy Engine RGPD obligatoire.',
      },
      gemini: {
        short: 'modèles Gemini',
        description: 'Accès direct aux modèles Google Gemini via clé API.',
      },
      xai: {
        short: 'modèles Grok',
        description: 'Accès direct aux modèles xAI Grok via clé API.',
      },
      local: {
        short: 'auto-hébergé',
        description:
          'Connectez PULSAR CHU à un endpoint local ou auto-hébergé compatible OpenAI (vLLM, llama.cpp, Ollama, LM Studio…). Recommandé pour les données sensibles non anonymisées.',
      },
    },

    backToSignIn: 'Retour à la connexion',
    getKey: 'Obtenir une clé',
    replaceCurrent: 'Remplacer la valeur actuelle',
    pasteApiKey: 'Coller la clé API',
    couldNotSave: 'Impossible d\'enregistrer les identifiants.',
    connecting: 'Connexion en cours',
    update: 'Mettre à jour',

    // Sous-titres des flux OAuth — affichés sous le nom du fournisseur
    flowSubtitles: {
      pkce: 'Ouvre votre navigateur pour vous connecter, puis revient ici automatiquement',
      // device_code = flux ChatGPT : code OTP affiché → saisie sur chatgpt.com/link
      device_code:
        'Affiche un code à saisir sur la page de vérification — PULSAR CHU se connecte automatiquement',
      loopback:
        'Ouvre votre navigateur pour vous connecter — PULSAR CHU se connecte automatiquement',
      external:
        'Connectez-vous une fois dans votre terminal, puis revenez pour dialoguer',
    },

    startingSignIn: (provider) => `Démarrage de la connexion à ${provider}…`,
    verifyingCode: (provider) => `Vérification de votre code auprès de ${provider}…`,
    connectedProvider: (provider) => `${provider} connecté`,
    connectedPicking: (provider) =>
      `${provider} connecté. Sélection du modèle par défaut…`,
    signInFailed: 'Échec de la connexion. Veuillez réessayer.',
    pickDifferentProvider: 'Choisir un autre fournisseur',
    signInWith: (provider) => `Se connecter avec ${provider}`,

    // Flux PKCE / loopback (navigateur ouvert automatiquement, code à coller)
    openedBrowser: (provider) =>
      `Nous avons ouvert ${provider} dans votre navigateur.`,
    authorizeThere: 'Autorisez PULSAR CHU sur cette page.',
    copyAuthCode: 'Copiez le code d\'autorisation et collez-le ci-dessous.',
    pasteAuthCode: 'Coller le code d\'autorisation',
    reopenAuthPage: 'Rouvrir la page d\'autorisation',
    autoBrowser: (provider) =>
      `Nous avons ouvert ${provider} dans votre navigateur. Autorisez PULSAR CHU et vous serez connecté automatiquement — rien à copier ni à coller.`,
    reopenSignInPage: 'Rouvrir la page de connexion',
    waitingAuthorize: 'En attente de votre autorisation…',

    // Flux externe / CLI (Copilot ACP, Gemini CLI…)
    externalPending: (provider) =>
      `${provider} s\'authentifie via son propre outil en ligne de commande. Exécutez cette commande dans un terminal, puis revenez et cliquez sur "Je suis connecté" :`,
    signedIn: 'Je suis connecté',

    // -------------------------------------------------------------------------
    // Flux Device Code — ChatGPT (abonnement Plus / Team / Enterprise)
    //
    // Fonctionnement :
    //   1. hermes-agent appelle l'endpoint OAuth de ChatGPT
    //   2. Un code OTP (ex: "ABCD-1234") est retourné et affiché dans l'UI
    //   3. L'utilisateur se rend sur chatgpt.com/link et saisit ce code
    //   4. hermes-agent poll l'endpoint jusqu'à validation
    //   5. Un access_token JWT est stocké dans ~/.hermes/auth.json
    //   6. Toutes les requêtes suivantes passent par chatgpt.com/backend-api/codex
    //
    // Le même flux s'applique au provider "nous" (Nous Portal).
    // -------------------------------------------------------------------------
    deviceCodeOpened: (provider) =>
      `Nous avons ouvert ${provider} dans votre navigateur. Saisissez ce code sur la page de vérification :`,
    reopenVerification: 'Rouvrir la page de vérification',

    // Textes spécifiques au flux device_code ChatGPT
    chatgptDeviceCode: {
      title: 'Connexion via abonnement ChatGPT',
      subtitle: 'Fonctionne avec les abonnements ChatGPT Plus, Team et Enterprise',
      instructions: [
        'La page chatgpt.com/link s\'est ouverte dans votre navigateur.',
        'Connectez-vous à votre compte ChatGPT si ce n\'est pas déjà fait.',
        'Saisissez le code affiché ci-dessous sur cette page.',
        'PULSAR CHU se connectera automatiquement une fois le code validé.',
      ],
      codeLabel: 'Votre code d\'appairage',
      codeCopied: 'Code copié !',
      codeCopyHint: 'Cliquez sur le code pour le copier',
      waitingValidation: 'En attente de validation sur chatgpt.com/link…',
      reopenPage: 'Rouvrir chatgpt.com/link',
      subscriptionRequired:
        'Un abonnement ChatGPT actif (Plus, Team ou Enterprise) est requis.',
      privacyNote:
        '⚕️ Note RGPD : Le Privacy Engine CHU anonymise automatiquement toutes les données de santé avant envoi à ChatGPT.',
      privacyNoteDisabled:
        '⚠️ Avertissement : Le Privacy Engine est désactivé. Aucune donnée de santé identifiante ne doit être transmise.',
      modelsAvailable: 'Modèles disponibles : GPT-4o, o1, o3, GPT-5 (selon votre abonnement)',
    },

    // Textes spécifiques à Azure OpenAI
    azureOpenai: {
      title: 'Azure OpenAI (Recommandé CHU)',
      subtitle: 'Hébergement souverain sur infrastructure Microsoft Azure France',
      endpointLabel: 'Endpoint Azure OpenAI',
      endpointPlaceholder: 'https://votre-ressource.openai.azure.com',
      apiKeyLabel: 'Clé API Azure OpenAI',
      apiKeyPlaceholder: 'Collez votre clé API Azure ici',
      deploymentLabel: 'Nom du déploiement (modèle)',
      deploymentPlaceholder: 'gpt-4o, gpt-4-turbo…',
      hdsNote:
        '✅ Hébergement HDS compatible — données de santé autorisées avec Privacy Engine actif.',
      testConnection: 'Tester la connexion',
      testSuccess: 'Connexion Azure OpenAI réussie.',
      testFailed:
        'Échec de la connexion. Vérifiez l\'endpoint et la clé API.',
    },

    // Textes spécifiques à l'endpoint local / auto-hébergé
    localEndpoint: {
      title: 'Endpoint local ou auto-hébergé',
      subtitle: 'Compatible vLLM, Ollama, LM Studio, llama.cpp',
      baseUrlLabel: 'URL de base (endpoint OpenAI-compatible)',
      baseUrlPlaceholder: 'http://127.0.0.1:8000/v1',
      apiKeyLabel: 'Clé API (optionnel)',
      apiKeyPlaceholder: 'Laissez vide si non requis',
      modelLabel: 'Modèle par défaut',
      modelPlaceholder: 'Hermes-3-Llama-3.1-70B, mistral-7b…',
      sovereignNote:
        '🏥 Mode souverain : les données ne quittent pas votre infrastructure.',
    },
  },

  // ---------------------------------------------------------------------------
  // MODÈLES — Sélection et configuration
  // ---------------------------------------------------------------------------
  models: {
    title: 'Sélection du modèle',
    searchPlaceholder: 'Rechercher un modèle…',
    noResults: 'Aucun modèle trouvé',
    loading: 'Chargement des modèles…',
    active: 'Modèle actif',
    recommended: 'Recommandé CHU',
    contextWindow: 'Fenêtre de contexte',
    costPer1k: 'Coût / 1k tokens',
    free: 'Gratuit',
    categories: {
      sovereign: '🏥 Souverain (auto-hébergé)',
      azure: '☁️ Azure OpenAI (HDS)',
      chatgpt: '💬 ChatGPT (abonnement)',
      api: '🔑 API (clé requise)',
      local: '💻 Local',
    },
  },

  // ---------------------------------------------------------------------------
  // AGENTS CHU — Spécialisés par domaine hospitalier
  // ---------------------------------------------------------------------------
  agents: {
    title: 'Agents Spécialisés CHU',
    description: 'Activez les agents adaptés à votre service',
    active: 'Agent actif',
    inactive: 'Agent inactif',
    activate: 'Activer',
    deactivate: 'Désactiver',
    configure: 'Configurer',
    list: {
      clinique: {
        name: 'Agent Clinique',
        description:
          'Aide à la décision médicale, synthèse de dossiers, protocoles de soins, interactions médicamenteuses.',
        badge: '⚕️ Clinique',
      },
      administratif: {
        name: 'Agent Administratif',
        description:
          'Gestion des admissions, facturation, codage PMSI, courriers médicaux, certificats.',
        badge: '📋 Administratif',
      },
      logistique: {
        name: 'Agent Logistique',
        description:
          'Gestion des stocks, planification des blocs, suivi des équipements, commandes.',
        badge: '📦 Logistique',
      },
      recherche: {
        name: 'Agent Recherche',
        description:
          'Veille bibliographique PubMed, analyse d\'essais cliniques, rédaction de protocoles.',
        badge: '🔬 Recherche',
      },
      qualite: {
        name: 'Agent Qualité',
        description:
          'Suivi des indicateurs qualité, gestion des événements indésirables, préparation des certifications HAS.',
        badge: '✅ Qualité',
      },
    },
  },

  // ---------------------------------------------------------------------------
  // PRIVACY ENGINE — Anonymisation RGPD
  // ---------------------------------------------------------------------------
  privacy: {
    title: 'Privacy Engine (Anonymisation RGPD)',
    description:
      'Contrôle de l\'anonymisation automatique des données de santé (PHI/DCP)',
    status: {
      active: '🔒 Anonymisation active',
      inactive: '⚠️ Anonymisation inactive',
      glassBreak: '🚨 Glass-Break actif',
    },
    enable: 'Activer l\'anonymisation',
    enableDesc:
      'Anonymise les noms, NIR, IPP, adresses et autres données identifiantes avant l\'envoi au modèle.',
    disable: 'Désactiver',
    disableWarning:
      'Attention : désactiver l\'anonymisation expose des données de santé identifiantes au fournisseur LLM.',
    glassBreak: {
      title: 'Mode Glass-Break (Urgence médicale)',
      description:
        'Suspend temporairement l\'anonymisation pour les situations d\'urgence nécessitant un contexte complet.',
      activate: 'Activer le Glass-Break',
      deactivate: 'Désactiver le Glass-Break',
      reasonLabel: 'Justification médicale (obligatoire)',
      reasonPlaceholder:
        'Décrivez la situation d\'urgence justifiant la levée d\'anonymat…',
      reasonMinLength: 'La justification doit comporter au moins 20 caractères.',
      durationLabel: 'Durée de suspension (minutes)',
      active: '⚠️ MODE GLASS-BREAK ACTIF — Anonymisation suspendue',
      activeUntil: (time) => `Glass-Break actif jusqu\'à ${time}`,
      auditNote:
        'Cet événement est tracé dans le journal d\'audit ISO 27001.',
    },
    stats: {
      title: 'Statistiques d\'anonymisation',
      totalProcessed: 'Flux traités',
      entitiesFound: 'Entités PHI détectées',
      entitiesAnonymized: 'Entités anonymisées',
      glassBreakCount: 'Événements Glass-Break',
      lastActivity: 'Dernière activité',
    },
    entities: {
      title: 'Types d\'entités détectées',
      PERSON: 'Noms de personnes',
      IPP: 'Identifiants patients (IPP)',
      NIR: 'Numéros de sécurité sociale (NIR)',
      DATE: 'Dates de naissance / événements',
      ADDRESS: 'Adresses',
      PHONE: 'Numéros de téléphone',
      EMAIL: 'Adresses email',
      RPPS: 'Numéros RPPS (médecins)',
      FINESS: 'Numéros FINESS (établissements)',
    },
  },

  // ---------------------------------------------------------------------------
  // PARAMÈTRES — Configuration générale
  // ---------------------------------------------------------------------------
  settings: {
    title: 'Paramètres PULSAR CHU',
    sections: {
      general: 'Général',
      models: 'Modèles IA',
      providers: 'Fournisseurs',
      privacy: 'Privacy Engine (RGPD)',
      agents: 'Agents CHU',
      security: 'Sécurité & Audit',
      about: 'À propos',
    },
    providers: {
      title: 'Fournisseurs de modèles',
      description:
        'Configurez vos fournisseurs d\'IA. Le Privacy Engine RGPD s\'applique à tous les flux.',
      addProvider: 'Ajouter un fournisseur',
      editProvider: 'Modifier',
      removeProvider: 'Retirer',
      testConnection: 'Tester',
      types: {
        'azure-openai': {
          name: 'Azure OpenAI',
          description:
            'Recommandé CHU — hébergement souverain HDS sur Azure France',
          authType: 'Clé API + Endpoint Azure',
        },
        'openai-codex': {
          name: 'ChatGPT (abonnement)',
          description:
            'Connexion via votre abonnement ChatGPT Plus, Team ou Enterprise. Aucune clé API requise — authentification par code d\'appairage sur chatgpt.com/link.',
          authType: 'Code d\'appairage (chatgpt.com/link)',
          howToConnect:
            'Cliquez sur "Se connecter" — un code s\'affichera. Rendez-vous sur chatgpt.com/link et saisissez ce code pour autoriser PULSAR CHU.',
          subscriptionNote:
            'Requiert un abonnement ChatGPT actif (Plus à partir de 20 $/mois).',
          privacyWarning:
            'Les données envoyées à ChatGPT sont traitées par OpenAI (hors UE). Le Privacy Engine RGPD doit être actif.',
        },
        'openai-api': {
          name: 'OpenAI API',
          description: 'Accès via clé API OpenAI. Données traitées hors UE.',
          authType: 'Clé API (OPENAI_API_KEY)',
        },
        nous: {
          name: 'Nous Portal (Hermes natif)',
          description:
            'Accès aux modèles Hermes via le portail DSIO CHU de Guyane. Authentification OAuth device_code.',
          authType: 'OAuth (code d\'appairage)',
        },
        ollama: {
          name: 'Ollama (local)',
          description:
            'Modèles exécutés localement via Ollama. Données souveraines.',
          authType: 'Aucune authentification requise',
        },
        vllm: {
          name: 'vLLM (auto-hébergé)',
          description:
            'Endpoint vLLM auto-hébergé. Compatible Hermes-3, Mistral, LLaMA…',
          authType: 'Clé API optionnelle',
        },
        openrouter: {
          name: 'OpenRouter',
          description: 'Accès à 300+ modèles via une seule clé.',
          authType: 'Clé API (OPENROUTER_API_KEY)',
        },
        copilot: {
          name: 'GitHub Copilot',
          description: 'Accès via token GitHub Copilot.',
          authType: 'Token GitHub (GH_TOKEN)',
        },
        anthropic: {
          name: 'Anthropic Claude',
          description: 'Modèles Claude via clé API ou OAuth PKCE.',
          authType: 'Clé API ou OAuth',
        },
        gemini: {
          name: 'Google Gemini',
          description: 'Modèles Gemini via clé API Google AI Studio.',
          authType: 'Clé API (GEMINI_API_KEY)',
        },
        lmstudio: {
          name: 'LM Studio (local)',
          description: 'Modèles exécutés localement via LM Studio.',
          authType: 'Aucune authentification requise',
        },
        custom: {
          name: 'Endpoint personnalisé',
          description: 'Tout endpoint compatible OpenAI.',
          authType: 'Configurable',
        },
      },
    },
    privacy: {
      title: 'Privacy Engine (Anonymisation)',
      description: 'Gère l\'anonymisation automatique des données de santé (PHI).',
      enable: 'Activer l\'anonymisation',
      enableDesc:
        'Anonymise les noms, NIR, IPP et adresses avant l\'envoi au modèle.',
      glassBreak: 'Mode Glass-Break (Urgence)',
      glassBreakDesc:
        'Désactive temporairement l\'anonymisation. Requiert une justification tracée.',
      glassBreakReason: 'Justification de la levée d\'anonymat (min 20 caractères)',
      glassBreakDuration: 'Durée (minutes)',
      glassBreakActive: '⚠️ MODE GLASS-BREAK ACTIF',
    },
    agents: {
      title: 'Agents Spécialisés',
      description: 'Configuration des agents hospitaliers',
      clinical: 'Agent Clinique',
      admin: 'Agent Administratif',
      logistics: 'Agent Logistique',
      research: 'Agent Recherche',
      quality: 'Agent Qualité',
    },
    security: {
      title: 'Sécurité & Audit ISO 27001',
      auditLog: 'Journal d\'audit',
      exportAudit: 'Exporter le journal',
      clearAudit: 'Effacer le journal',
      sessionTimeout: 'Délai d\'expiration de session (minutes)',
      requireJustification: 'Exiger une justification pour le Glass-Break',
      dataRetention: 'Durée de conservation des journaux (jours)',
    },
    about: {
      title: 'À propos de PULSAR CHU',
      version: 'Version',
      basedOn: 'Basé sur Hermes Agent (DSIO CHU de Guyane)',
      license: 'Licence Apache 2.0',
      compliance: 'Conformité ISO 27001 & HDS',
      github: 'Dépôt GitHub',
    },
  },

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS & ERREURS
  // ---------------------------------------------------------------------------
  notifications: {
    region: 'Notifications',
    hide: 'Masquer',
    show: 'Afficher',
    more: (count) =>
      `${count} notification${count > 1 ? 's' : ''} supplémentaire${count > 1 ? 's' : ''}`,
    clearAll: 'Tout effacer',
    dismiss: 'Fermer la notification',
    details: 'Détails',
    copyDetail: 'Copier les détails',
    copyDetailFailed: 'Impossible de copier les détails',
    backendOutOfDateTitle: 'Backend obsolète',
    backendOutOfDateMessage: 'Veuillez mettre à jour le backend PULSAR CHU.',
  },

  // ---------------------------------------------------------------------------
  // AUDIT & CONFORMITÉ ISO 27001
  // ---------------------------------------------------------------------------
  audit: {
    title: 'Journal d\'audit ISO 27001',
    description: 'Traçabilité complète des actions et des flux de données',
    columns: {
      timestamp: 'Horodatage',
      user: 'Utilisateur',
      action: 'Action',
      provider: 'Fournisseur',
      anonymized: 'Anonymisé',
      glassBreak: 'Glass-Break',
      hash: 'Empreinte SHA-256',
    },
    actions: {
      message_sent: 'Message envoyé',
      message_received: 'Réponse reçue',
      anonymization_applied: 'Anonymisation appliquée',
      glass_break_activated: 'Glass-Break activé',
      glass_break_deactivated: 'Glass-Break désactivé',
      provider_connected: 'Fournisseur connecté',
      provider_disconnected: 'Fournisseur déconnecté',
      settings_changed: 'Paramètres modifiés',
      session_started: 'Session démarrée',
      session_ended: 'Session terminée',
    },
    export: {
      title: 'Exporter le journal d\'audit',
      format: 'Format',
      dateRange: 'Période',
      includeHashes: 'Inclure les empreintes SHA-256',
      button: 'Exporter',
    },
    noEntries: 'Aucune entrée dans le journal d\'audit.',
    loadMore: 'Charger plus',
  },

  // ---------------------------------------------------------------------------
  // CHAT — Interface de dialogue
  // ---------------------------------------------------------------------------
  chat: {
    newConversation: 'Nouvelle conversation',
    placeholder: 'Posez votre question à PULSAR CHU…',
    placeholderAnonymized: 'Posez votre question (données anonymisées avant envoi)…',
    thinking: 'PULSAR CHU réfléchit…',
    generatingResponse: 'Génération de la réponse…',
    stopGeneration: 'Arrêter la génération',
    copyMessage: 'Copier le message',
    regenerate: 'Régénérer',
    editMessage: 'Modifier le message',
    deleteMessage: 'Supprimer le message',
    agentLabel: 'Agent actif',
    privacyActive: '🔒 Privacy Engine actif — données anonymisées',
    privacyInactive: '⚠️ Privacy Engine inactif',
    glassBreakWarning: '🚨 Mode Glass-Break actif — anonymisation suspendue',
    sessionId: 'Session',
    tokenCount: 'Tokens utilisés',
  },
}
