# HERMES CHU — Dockerfile Interface Web (React/Vite)
# Multi-stage : build Node.js → serve Nginx

# ── Étape 1 : Build ──────────────────────────────────────────────────────────
FROM node:22-alpine AS builder

WORKDIR /build

COPY src/web-ui/package.json src/web-ui/package-lock.json* ./
RUN npm ci --silent

COPY src/web-ui/ .
RUN npm run build

# ── Étape 2 : Nginx sécurisé ──────────────────────────────────────────────────
FROM nginx:1.27-alpine AS final

LABEL maintainer="equipe-hermes@chu.local"
LABEL version="1.0.0"
LABEL description="HERMES CHU — Interface Web"

# Configuration Nginx sécurisée
COPY infrastructure/nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /build/dist /usr/share/nginx/html

# Utilisateur non-root
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -q --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
