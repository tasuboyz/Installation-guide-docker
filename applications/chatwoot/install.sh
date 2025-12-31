#!/bin/bash

# Chatwoot Installation Script
# Installazione GUIDATA di Chatwoot con supporto nginx-proxy + SSL automatico
# Run with: sudo ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

# Header
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           CHATWOOT - INSTALLAZIONE GUIDATA                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    print_error "Questo script deve essere eseguito con privilegi root. Usa: sudo ./install.sh"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker non è installato. Installa Docker prima di continuare."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose non disponibile. Installalo prima di continuare."
    exit 1
fi

INSTALL_DIR="$(pwd)"

# ============================================================================
# STEP 1: Rete Docker
# ============================================================================
echo -e "${CYAN}STEP 1/6${NC} - Rete Docker"
echo ""

# Rileva reti esistenti
EXISTING_NETWORKS=$(docker network ls --format '{{.Name}}' | grep -v -E '^(bridge|host|none)$' || true)

if [[ -n "$EXISTING_NETWORKS" ]]; then
    print_info "Reti Docker esistenti:"
    echo "$EXISTING_NETWORKS" | while read net; do echo "   - $net"; done
    echo ""
fi

read -p "Nome rete Docker [default: n8n-net]: " DOCKER_NETWORK
DOCKER_NETWORK=${DOCKER_NETWORK:-n8n-net}

# Crea rete se non esiste
if ! docker network inspect "$DOCKER_NETWORK" &>/dev/null; then
    docker network create "$DOCKER_NETWORK"
    print_status "Rete '$DOCKER_NETWORK' creata"
else
    print_status "Rete '$DOCKER_NETWORK' già esistente"
fi

# ============================================================================
# STEP 2: Configurazione Dominio (opzionale)
# ============================================================================
echo ""
echo -e "${CYAN}STEP 2/6${NC} - Configurazione Dominio (opzionale)"
echo ""
print_info "Se vuoi esporre Chatwoot con un sottodominio e SSL automatico,"
print_info "inserisci il dominio qui. Altrimenti premi INVIO per accesso locale."
echo ""

read -p "Dominio (es. chatwoot.example.com) [vuoto = solo locale]: " CHATWOOT_DOMAIN

USE_PROXY=false
LETSENCRYPT_EMAIL=""

if [[ -n "$CHATWOOT_DOMAIN" ]]; then
    USE_PROXY=true
    
    # Verifica DNS
    print_info "Verifica DNS per $CHATWOOT_DOMAIN..."
    RESOLVED_IP=$(dig +short "$CHATWOOT_DOMAIN" 2>/dev/null | head -1)
    if [[ -n "$RESOLVED_IP" ]]; then
        print_status "DNS: $CHATWOOT_DOMAIN → $RESOLVED_IP"
    else
        print_warning "DNS non risolto per $CHATWOOT_DOMAIN"
        print_warning "Assicurati che il DNS sia configurato prima di procedere."
    fi
    
    # ============================================================================
    # STEP 3: Email Let's Encrypt
    # ============================================================================
    echo ""
    echo -e "${CYAN}STEP 3/6${NC} - Email per Let's Encrypt"
    echo ""
    
    read -p "Email per certificati SSL: " LETSENCRYPT_EMAIL
    while [[ -z "$LETSENCRYPT_EMAIL" ]]; do
        print_error "Email obbligatoria per SSL"
        read -p "Email per certificati SSL: " LETSENCRYPT_EMAIL
    done
    
    print_status "Email: $LETSENCRYPT_EMAIL"
else
    print_info "Installazione in modalità locale (nessun dominio configurato)"
    echo ""
    echo -e "${CYAN}STEP 3/6${NC} - Saltato (nessun dominio)"
fi

# ============================================================================
# STEP 4: Generazione credenziali
# ============================================================================
echo ""
echo -e "${CYAN}STEP 4/6${NC} - Generazione credenziali"
echo ""

# Generate secrets
SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)

print_status "Credenziali generate:"
echo "   POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "   REDIS_PASSWORD=$REDIS_PASSWORD"

# Crea .env minimale e funzionante (NON copiare .env.example upstream che ha problemi di formattazione)
cat > .env << ENV_EOF
# Chatwoot Environment Configuration
# Generato da install.sh

# === Credenziali ===
SECRET_KEY_BASE=${SECRET_KEY_BASE}
RAILS_ENV=production

# === Database ===
POSTGRES_HOST=chatwoot_postgres
POSTGRES_DB=chatwoot
# Compatibility: some entrypoints/readers expect POSTGRES_USERNAME or PGUSER
POSTGRES_USER=postgres
POSTGRES_USERNAME=postgres
PGUSER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# === Redis ===
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
REDIS_PASSWORD=${REDIS_PASSWORD}

# === Applicazione ===
RAILS_MAX_THREADS=5
RAILS_LOG_TO_STDOUT=true
LOG_LEVEL=info
ENABLE_ACCOUNT_SIGNUP=true
ACTIVE_STORAGE_SERVICE=local
ENV_EOF

# Configura dominio se specificato
if [[ "$USE_PROXY" == "true" ]]; then
    cat >> .env << ENV_EOF

# === Dominio e SSL ===
FRONTEND_URL=https://${CHATWOOT_DOMAIN}
FORCE_SSL=true

# === nginx-proxy + acme-companion ===
VIRTUAL_HOST=${CHATWOOT_DOMAIN}
VIRTUAL_PORT=3000
LETSENCRYPT_HOST=${CHATWOOT_DOMAIN}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
DOCKER_NETWORK=${DOCKER_NETWORK}
ENV_EOF
    print_status "Configurazione dominio aggiunta a .env"
else
    cat >> .env << ENV_EOF

# === Configurazione Locale ===
FRONTEND_URL=http://0.0.0.0:3000
FORCE_SSL=false
ENV_EOF
    print_status "Configurazione locale aggiunta a .env"
fi

# ============================================================================
# STEP 5: Aggiorna docker-compose.yaml
# ============================================================================
echo ""
echo -e "${CYAN}STEP 5/6${NC} - Configurazione Docker Compose"
echo ""

# Crea docker-compose.yaml configurato
cat > docker-compose.yaml << 'COMPOSE_EOF'
version: '3'

services:
  base: &base
    image: chatwoot/chatwoot:latest
    env_file: .env
    volumes:
      - storage_data:/app/storage

  rails:
    <<: *base
    depends_on:
      - postgres
      - redis
COMPOSE_EOF

# Aggiungi configurazione porte/expose basata su USE_PROXY
if [[ "$USE_PROXY" == "true" ]]; then
    cat >> docker-compose.yaml << 'COMPOSE_EOF'
    # Modalità proxy: solo expose interno, niente porte pubbliche
    expose:
      - "3000"
    environment:
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
      - VIRTUAL_HOST=${VIRTUAL_HOST}
      - VIRTUAL_PORT=3000
      - LETSENCRYPT_HOST=${LETSENCRYPT_HOST}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
COMPOSE_EOF
else
    cat >> docker-compose.yaml << 'COMPOSE_EOF'
    # Modalità locale: porta esposta su host
    ports:
      - '3000:3000'
    expose:
      - "3000"
    environment:
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
COMPOSE_EOF
fi

# Continua con il resto del compose
cat >> docker-compose.yaml << 'COMPOSE_EOF'
    entrypoint: docker/entrypoints/rails.sh
    command: ['bundle', 'exec', 'rails', 's', '-p', '3000', '-b', '0.0.0.0']
    networks:
      - default
COMPOSE_EOF

# Aggiungi network esterna se proxy
if [[ "$USE_PROXY" == "true" ]]; then
    cat >> docker-compose.yaml << COMPOSE_EOF
      - ${DOCKER_NETWORK}
COMPOSE_EOF
fi

cat >> docker-compose.yaml << 'COMPOSE_EOF'
    restart: always

  sidekiq:
    <<: *base
    depends_on:
      - postgres
      - redis
    environment:
      - NODE_ENV=production
      - RAILS_ENV=production
      - INSTALLATION_ENV=docker
    command: ['bundle', 'exec', 'sidekiq', '-C', 'config/sidekiq.yml']
    restart: always

  postgres:
    image: pgvector/pgvector:pg16
    restart: always
    env_file:
      - .env
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    restart: always
    command: ["sh", "-c", "redis-server --requirepass \"$REDIS_PASSWORD\""]
    env_file: .env
    volumes:
      - redis_data:/data

volumes:
  storage_data:
  postgres_data:
  redis_data:

networks:
  default:
    driver: bridge
COMPOSE_EOF

# Aggiungi network esterna se proxy
if [[ "$USE_PROXY" == "true" ]]; then
    cat >> docker-compose.yaml << COMPOSE_EOF
  ${DOCKER_NETWORK}:
    external: true
COMPOSE_EOF
fi

print_status "docker-compose.yaml generato"

# ============================================================================
# STEP 6: Avvio servizi
# ============================================================================
echo ""
echo -e "${CYAN}STEP 6/6${NC} - Avvio servizi"
echo ""

print_info "Preparazione database..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

print_info "Avvio Chatwoot..."
docker compose up -d

# Attendi che i servizi siano pronti
sleep 5

# Verifica stato
if docker compose ps | grep -q "rails.*running\|rails.*Up"; then
    print_status "Chatwoot avviato con successo!"
else
    print_warning "Verifica lo stato con: docker compose ps"
fi

# ============================================================================
# RIEPILOGO FINALE
# ============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              INSTALLAZIONE COMPLETATA                         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ "$USE_PROXY" == "true" ]]; then
    echo -e "   ${GREEN}Dominio:${NC}  https://$CHATWOOT_DOMAIN"
    echo -e "   ${GREEN}Email:${NC}    $LETSENCRYPT_EMAIL"
    echo -e "   ${GREEN}Rete:${NC}     $DOCKER_NETWORK"
    echo ""
    print_info "Il certificato SSL verrà emesso automaticamente da acme-companion."
    print_info "Verifica i log con: docker logs -f nginx-proxy-acme"
    echo ""
    print_warning "Assicurati che nginx-proxy e nginx-proxy-acme siano in esecuzione"
    print_warning "sulla stessa rete ($DOCKER_NETWORK)."
else
    echo -e "   ${GREEN}Accesso locale:${NC}  http://localhost:3000"
    echo -e "   ${GREEN}Accesso LAN:${NC}     http://<IP_SERVER>:3000"
    echo ""
    print_info "Per esporre con dominio e SSL, riesegui lo script e inserisci un dominio."
fi

echo ""
echo "Comandi utili:"
echo "   docker compose ps          # Stato servizi"
echo "   docker compose logs -f     # Log in tempo reale"
echo "   docker compose down        # Ferma tutto"
echo ""