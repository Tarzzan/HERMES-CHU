-- HERMES CHU — Initialisation de la base de données
-- Conformité : ISO 27001 — Journalisation immuable — RGPD

-- Création des bases de données
CREATE DATABASE hermes_qualite;
CREATE DATABASE keycloak;

-- Extension pour UUID
\c hermes;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Table : Sessions ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    id_utilisateur  VARCHAR(255) NOT NULL,
    service         VARCHAR(100),
    role            VARCHAR(50) NOT NULL,
    cree_le         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expire_le       TIMESTAMPTZ NOT NULL,
    actif           BOOLEAN NOT NULL DEFAULT TRUE,
    anonymisation   BOOLEAN NOT NULL DEFAULT TRUE,
    ip_source       INET,
    user_agent      TEXT
);

CREATE INDEX idx_sessions_utilisateur ON sessions(id_utilisateur);
CREATE INDEX idx_sessions_actif ON sessions(actif, expire_le);

-- ── Table : Journal d'audit (IMMUABLE) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS journal_audit (
    id              BIGSERIAL PRIMARY KEY,
    horodatage      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_session      UUID REFERENCES sessions(id),
    id_utilisateur  VARCHAR(255) NOT NULL,
    service         VARCHAR(100),
    evenement       VARCHAR(100) NOT NULL,
    details         TEXT,
    niveau          VARCHAR(20) NOT NULL CHECK (niveau IN ('INFO', 'AVERTISSEMENT', 'ALERTE', 'ERREUR', 'CRITIQUE')),
    etat_agent      VARCHAR(50),
    hash_precedent  VARCHAR(64),  -- Hash de l'entrée précédente (chaîne d'intégrité)
    hash_entree     VARCHAR(64) NOT NULL  -- SHA-256 de cette entrée
);

-- Interdire UPDATE et DELETE sur le journal d'audit
CREATE RULE journal_audit_no_update AS ON UPDATE TO journal_audit DO INSTEAD NOTHING;
CREATE RULE journal_audit_no_delete AS ON DELETE TO journal_audit DO INSTEAD NOTHING;

CREATE INDEX idx_audit_horodatage ON journal_audit(horodatage DESC);
CREATE INDEX idx_audit_utilisateur ON journal_audit(id_utilisateur);
CREATE INDEX idx_audit_niveau ON journal_audit(niveau);
CREATE INDEX idx_audit_session ON journal_audit(id_session);

-- ── Table : Incidents ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS incidents (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    horodatage_detection    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    type_incident           VARCHAR(50) NOT NULL,
    severite                VARCHAR(20) NOT NULL CHECK (severite IN ('FAIBLE', 'MOYEN', 'ELEVE', 'CRITIQUE')),
    description             TEXT NOT NULL,
    service_concerne        VARCHAR(100) NOT NULL,
    id_session_impliquee    UUID,
    statut                  VARCHAR(20) NOT NULL DEFAULT 'OUVERT' CHECK (statut IN ('OUVERT', 'EN_COURS', 'RESOLU', 'CLOS')),
    responsable             VARCHAR(255),
    actions_correctives     TEXT,
    date_resolution         TIMESTAMPTZ,
    cree_par                VARCHAR(255),
    modifie_le              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_incidents_statut ON incidents(statut);
CREATE INDEX idx_incidents_severite ON incidents(severite);
CREATE INDEX idx_incidents_service ON incidents(service_concerne);

-- ── Table : Métriques (time-series) ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS metriques (
    id              BIGSERIAL PRIMARY KEY,
    horodatage      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    agent           VARCHAR(50) NOT NULL,
    nb_requetes     INTEGER NOT NULL DEFAULT 0,
    nb_succes       INTEGER NOT NULL DEFAULT 0,
    nb_echecs       INTEGER NOT NULL DEFAULT 0,
    latence_ms      FLOAT,
    tokens_entree   INTEGER,
    tokens_sortie   INTEGER,
    garde_fous      INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_metriques_horodatage ON metriques(horodatage DESC);
CREATE INDEX idx_metriques_agent ON metriques(agent);

-- ── Table : Opérations d'anonymisation ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS journal_anonymisation (
    id              BIGSERIAL PRIMARY KEY,
    horodatage      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_session      UUID,
    id_utilisateur  VARCHAR(255) NOT NULL,
    operation       VARCHAR(20) NOT NULL CHECK (operation IN ('ACTIVATION', 'DESACTIVATION', 'TRAITEMENT')),
    justification   TEXT,
    nb_entites      INTEGER,
    types_phi       TEXT[],
    duree_ms        FLOAT
);

CREATE INDEX idx_anon_horodatage ON journal_anonymisation(horodatage DESC);
CREATE INDEX idx_anon_operation ON journal_anonymisation(operation);

-- ── Commentaires de conformité ────────────────────────────────────────────────
COMMENT ON TABLE journal_audit IS 'Journal d''audit immuable — ISO 27001 A.12.4 — Conservation 10 ans';
COMMENT ON TABLE sessions IS 'Sessions utilisateurs — TTL géré par l''application';
COMMENT ON TABLE incidents IS 'Incidents de sécurité et qualité — ISO 27001 A.16';
COMMENT ON TABLE journal_anonymisation IS 'Traçabilité des opérations d''anonymisation — RGPD Art. 25';
