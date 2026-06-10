import { useState } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import DialoguePage from './pages/DialoguePage'
import SupervisionPage from './pages/SupervisionPage'
import AdministrationPage from './pages/AdministrationPage'
import LoginPage from './pages/LoginPage'
import { AuthProvider, useAuth } from './contexts/AuthContext'

function AppRoutes() {
  const { estConnecte } = useAuth()

  if (!estConnecte) return <LoginPage />

  return (
    <Layout>
      <Routes>
        <Route path="/" element={<Navigate to="/dialogue" replace />} />
        <Route path="/dialogue" element={<DialoguePage />} />
        <Route path="/supervision" element={<SupervisionPage />} />
        <Route path="/administration" element={<AdministrationPage />} />
        <Route path="*" element={<Navigate to="/dialogue" replace />} />
      </Routes>
    </Layout>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}
