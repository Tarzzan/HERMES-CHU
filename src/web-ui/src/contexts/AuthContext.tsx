import { createContext, useContext, useState, useEffect, ReactNode } from 'react'

interface Utilisateur {
  id: string
  nom: string
  prenom: string
  email: string
  role: string
  service: string
  token: string
}

interface AuthContextType {
  utilisateur: Utilisateur | null
  estConnecte: boolean
  connexion: (identifiant: string, motDePasse: string) => Promise<void>
  deconnexion: () => void
  erreurConnexion: string | null
}

const AuthContext = createContext<AuthContextType | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [utilisateur, setUtilisateur] = useState<Utilisateur | null>(null)
  const [erreurConnexion, setErreurConnexion] = useState<string | null>(null)

  // Restauration de session depuis le localStorage
  useEffect(() => {
    const sessionSauvegardee = localStorage.getItem('hermes_session')
    if (sessionSauvegardee) {
      try {
        setUtilisateur(JSON.parse(sessionSauvegardee))
      } catch {
        localStorage.removeItem('hermes_session')
      }
    }
  }, [])

  const connexion = async (identifiant: string, motDePasse: string) => {
    setErreurConnexion(null)
    try {
      // TODO: Appel Keycloak OAuth2 (PKCE flow)
      // const reponse = await fetch(`${KEYCLOAK_URL}/realms/hermes-chu/protocol/openid-connect/token`, {...})
      
      // Simulation pour le développement
      if (identifiant === 'demo' && motDePasse === 'demo') {
        const userDemo: Utilisateur = {
          id: 'demo-001',
          nom: 'Dupont',
          prenom: 'Marie',
          email: 'marie.dupont@chu-demo.local',
          role: 'ROLE_CLINICIEN',
          service: 'Cardiologie',
          token: 'demo-token-jwt',
        }
        setUtilisateur(userDemo)
        localStorage.setItem('hermes_session', JSON.stringify(userDemo))
      } else {
        throw new Error('Identifiants incorrects')
      }
    } catch (err: any) {
      setErreurConnexion(err.message || 'Erreur de connexion')
    }
  }

  const deconnexion = () => {
    setUtilisateur(null)
    localStorage.removeItem('hermes_session')
    // TODO: Révocation du token Keycloak
  }

  return (
    <AuthContext.Provider value={{
      utilisateur,
      estConnecte: utilisateur !== null,
      connexion,
      deconnexion,
      erreurConnexion,
    }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth doit être utilisé dans AuthProvider')
  return ctx
}
