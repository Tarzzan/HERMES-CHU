# HERMES CHU — Dockerfile Privacy Engine
# Image multi-stage avec support GPU optionnel (pour NER CamemBERT-bio)

# ── Étape 1 : Build ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY src/privacy-engine/requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Étape 2 : Pré-téléchargement du modèle NER ───────────────────────────────
FROM builder AS model-downloader

ARG DOWNLOAD_MODEL=false
RUN if [ "$DOWNLOAD_MODEL" = "true" ]; then \
    /opt/venv/bin/python -c "\
from transformers import AutoTokenizer, AutoModelForTokenClassification; \
AutoTokenizer.from_pretrained('almanach/camembert-bio-medical', cache_dir='/models'); \
AutoModelForTokenClassification.from_pretrained('almanach/camembert-bio-medical', cache_dir='/models'); \
print('Modèle téléchargé avec succès.')"; \
fi

# ── Étape 3 : Image finale ────────────────────────────────────────────────────
FROM python:3.12-slim AS final

LABEL maintainer="equipe-hermes@chu.local"
LABEL version="1.0.0"
LABEL description="HERMES CHU — Privacy Engine (SAS d'Anonymisation)"

RUN groupadd --gid 1001 privacy && \
    useradd --uid 1001 --gid privacy --shell /bin/false --no-create-home privacy

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY --from=model-downloader /models /models
COPY src/privacy-engine/ /app/

RUN mkdir -p /var/log/hermes && \
    chown -R privacy:privacy /app /var/log/hermes

WORKDIR /app
USER privacy

ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
ENV TRANSFORMERS_CACHE=/models
ENV ENVIRONMENT=production

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8001/sante || exit 1

EXPOSE 8001

CMD ["uvicorn", "serveur_privacy:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "2"]
