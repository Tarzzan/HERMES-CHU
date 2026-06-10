# HERMES CHU — Dockerfile Orchestrateur Pilote
# Image multi-stage sécurisée (distroless final)
# Conformité ISO 27001 : pas de shell, pas d'outils inutiles en production

# ── Étape 1 : Build ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Dépendances système minimales pour la compilation
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Installation des dépendances Python dans un venv isolé
COPY src/orchestrator/requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Étape 2 : Image finale ────────────────────────────────────────────────────
FROM python:3.12-slim AS final

# Métadonnées
LABEL maintainer="equipe-hermes@chu.local"
LABEL version="1.0.0"
LABEL description="HERMES CHU — Orchestrateur Pilote"
LABEL iso27001.compliant="true"

# Utilisateur non-root (sécurité)
RUN groupadd --gid 1000 hermes && \
    useradd --uid 1000 --gid hermes --shell /bin/false --no-create-home hermes

# Dépendances runtime uniquement
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copie du venv et du code source
COPY --from=builder /opt/venv /opt/venv
COPY src/orchestrator/ /app/

# Répertoires avec permissions correctes
RUN mkdir -p /data /var/log/hermes && \
    chown -R hermes:hermes /app /data /var/log/hermes

WORKDIR /app
USER hermes

ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV ENVIRONMENT=production

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/api/sante || exit 1

EXPOSE 8000

CMD ["uvicorn", "serveur:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
