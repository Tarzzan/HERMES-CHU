# HERMES CHU — Dockerfile API Qualité
# Service de métriques, incidents et rapports qualité (port 8002)

# ── Étape 1 : Build ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY src/api-quality/requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Étape 2 : Image finale ────────────────────────────────────────────────────
FROM python:3.12-slim AS final

LABEL maintainer="equipe-hermes@chu.local"
LABEL version="1.0.0"
LABEL description="HERMES CHU — API Qualité (métriques, incidents, rapports)"

RUN groupadd --gid 1001 qualite && \
    useradd --uid 1001 --gid qualite --shell /bin/false --no-create-home qualite

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY src/api-quality/ /app/

RUN mkdir -p /var/log/hermes && \
    chown -R qualite:qualite /app /var/log/hermes

WORKDIR /app
USER qualite

ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV ENVIRONMENT=production

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8002/docs || exit 1

EXPOSE 8002

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002", "--workers", "2"]
