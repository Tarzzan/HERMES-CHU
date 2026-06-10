import type { Translations } from './types'

export const fr: Translations = {
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
    off: 'Désactivé'
  },
  boot: {
    ready: 'HERMES CHU est prêt',
    desktopBootFailedWithMessage: message => `Échec du démarrage : ${message}`,
    steps: {
      connectingGateway: 'Connexion à la passerelle hospitalière',
      loadingSettings: 'Chargement des paramètres CHU',
      loadingSessions: 'Chargement des sessions sécurisées',
      startingDesktopConnection: 'Démarrage de la connexion bureau',
      startingHermesDesktop: 'Démarrage de HERMES CHU…'
    },
    errors: {
      backgroundExited: 'Le processus en arrière-plan s\'est arrêté.',
      backgroundExitedDuringStartup: 'Le processus s\'est arrêté pendant le démarrage.',
      backendStopped: 'Backend arrêté',
      desktopBootFailed: 'Échec du démarrage de l\'application',
      gatewaySignInRequired: 'Authentification requise',
      ipcBridgeUnavailable: 'Le pont IPC est indisponible.'
    },
    failure: {
      title: "HERMES CHU n'a pas pu démarrer",
      description:
        "La passerelle sécurisée n'a pas répondu. Essayez une des options de récupération ci-dessous. Vos données et paramètres sont conservés.",
      remoteTitle: 'Authentification distante requise',
      remoteDescription:
        'Votre session distante a expiré. Reconnectez-vous pour continuer.',
      retry: 'Réessayer',
      repairInstall: 'Réparer l\'installation',
      useLocalGateway: 'Utiliser la passerelle locale',
      openLogs: 'Ouvrir les journaux',
      repairHint: 'La réparation relance l\'installation (peut prendre quelques minutes).',
      remoteSignInHint: 'Ouvre la fenêtre de connexion. Utilisez la passerelle locale pour basculer sur le backend intégré.',
      hideRecentLogs: 'Masquer les journaux',
      showRecentLogs: 'Afficher les journaux',
      signedInTitle: 'Connecté',
      signedInMessage: 'Reconnexion à la passerelle…',
      signInIncompleteTitle: 'Connexion incomplète',
      signInIncompleteMessage: 'La fenêtre s\'est fermée avant la fin de l\'authentification.',
      signInFailed: 'Échec de la connexion',
      signInToRemoteGateway: 'Se connecter à la passerelle',
      signInWithProvider: provider => `Se connecter avec ${provider}`,
      identityProvider: 'votre fournisseur d\'identité'
    }
  },
  notifications: {
    region: 'Notifications',
    hide: 'Masquer',
    show: 'Afficher',
    more: count => `${count} notification${count > 1 ? 's' : ''} supplémentaire${count > 1 ? 's' : ''}`,
    clearAll: 'Tout effacer',
    dismiss: 'Fermer la notification',
    details: 'Détails',
    copyDetail: 'Copier les détails',
    copyDetailFailed: 'Impossible de copier les détails',
    backendOutOfDateTitle: 'Backend obsolète',
    backendOutOfDateMessage: 'Veuillez mettre à jour le backend HERMES CHU.'
  },
  settings: {
    title: 'Paramètres HERMES CHU',
    sections: {
      general: 'Général',
      models: 'Modèles IA',
      privacy: 'Privacy Engine (RGPD)',
      agents: 'Agents CHU',
      security: 'Sécurité & Audit'
    },
    privacy: {
      title: 'Privacy Engine (Anonymisation)',
      description: 'Gère l\'anonymisation automatique des données de santé (PHI).',
      enable: 'Activer l\'anonymisation',
      enableDesc: 'Anonymise les noms, NIR, IPP et adresses avant l\'envoi au modèle.',
      glassBreak: 'Mode Glass-Break (Urgence)',
      glassBreakDesc: 'Désactive temporairement l\'anonymisation. Requis une justification tracée.',
      glassBreakReason: 'Justification de la levée d\'anonymat (min 20 caractères)',
      glassBreakDuration: 'Durée (minutes)',
      glassBreakActive: '⚠️ MODE GLASS-BREAK ACTIF'
    },
    agents: {
      title: 'Agents Spécialisés',
      description: 'Configuration des agents hospitaliers',
      clinical: 'Agent Clinique',
      admin: 'Agent Administratif',
      logistics: 'Agent Logistique',
      research: 'Agent Recherche',
      quality: 'Agent Qualité'
    }
  }
}
