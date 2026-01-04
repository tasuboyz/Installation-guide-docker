#!/bin/bash
# =============================================================================
# HELPER SCRIPT - Centralizzazione Domini Retell + Portainer
# Uso: ./setup-domains.sh
# Prerequisiti: WSL2, Docker, accesso sudo
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_header() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# =============================================================================
# STEP 0: VERIFICHE PRELIMINARI
# =============================================================================

print_header "VERIFICA PREREQUISITI"

# Verifica Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker non trovato. Installa Docker Desktop con WSL2"
    exit 1
fi

if ! docker ps &> /dev/null; then
    print_error "Docker non in esecuzione. Avvia Docker Desktop"
    exit 1
fi

print_status "Docker: OK"

# Verifica Docker Compose
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose non disponibile"
    exit 1
fi

print_status "Docker Compose: OK"

# Verifica rete
DOCKER_NETWORK="${DOCKER_NETWORK:-glpi-net}"
if ! docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK}$"; then
    print_warning "Rete '${DOCKER_NETWORK}' non esiste"
    read -p "Crearla? [Y/n]: " CREATE_NET
    CREATE_NET=${CREATE_NET:-y}
    if [[ "${CREATE_NET,,}" == "y" ]]; then
        docker network create "${DOCKER_NETWORK}"
        print_status "Rete creata: ${DOCKER_NETWORK}"
    fi
fi

print_status "Rete Docker: OK (${DOCKER_NETWORK})"

# =============================================================================
# CONFIGURAZIONE INTERATTIVA
# =============================================================================

print_header "CONFIGURAZIONE DOMINI CENTRALIZZATI"

echo "Questo script configura nginx-proxy + SSL per:"
echo "  • AI Voice Agent (Retell Backend)"
echo "  • Portainer"
echo "  • Altri servizi (n8n, Chatwoot, ecc.)"
echo ""

# Email Let's Encrypt
read -p "Email Let's Encrypt (vedi .env per valore salvato): " LETSENCRYPT_EMAIL
if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Email non valida"
    exit 1
fi

# Dominio principale
read -p "Dominio principale (es: tuodominio.com): " MAIN_DOMAIN

# Salva configurazione
cat > .env.domains << EOF
# Configurazione Domini - Generato $(date)
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
MAIN_DOMAIN=${MAIN_DOMAIN}
DOCKER_NETWORK=${DOCKER_NETWORK}

# Sottodomini Servizi
RETELL_BACKEND_SUBDOMAIN=ai.${MAIN_DOMAIN}
PORTAINER_SUBDOMAIN=portainer.${MAIN_DOMAIN}
N8N_SUBDOMAIN=automation.${MAIN_DOMAIN}
CHATWOOT_SUBDOMAIN=chat.${MAIN_DOMAIN}
EOF

print_status "Configurazione salvata: .env.domains"

# =============================================================================
# ESECUZIONE SCRIPT PRINCIPALE
# =============================================================================

print_header "AVVIO CONFIGURAZIONE NGINX-PROXY"

cd "$(dirname "$0")"

if [[ ! -f "install.sh" ]]; then
    print_error "install.sh non trovato in $(pwd)"
    exit 1
fi

chmod +x install.sh

echo "Esecuzione dello script automatico..."
echo ""

# Esegui in context di docker (con env caricato)
export DOCKER_NETWORK
export LETSENCRYPT_EMAIL

./install.sh

# =============================================================================
# POST-SETUP
# =============================================================================

print_header "CONFIGURAZIONE COMPLETATA"

echo ""
echo "✅ Servizi esposti:"
source .env.domains 2>/dev/null || true
echo "  • Retell Backend:  https://${RETELL_BACKEND_SUBDOMAIN}"
echo "  • Portainer:       https://${PORTAINER_SUBDOMAIN}"
echo ""

echo "📋 File di configurazione salvati:"
echo "  • .env.domains              (sottodomini e credenziali)"
echo "  • configs/                  (configurazione per servizio)"
echo "  • vhost-configs/            (configurazione nginx)"
echo ""

echo "🔍 Comandi utili:"
echo "  Monitoraggio certificati:"
echo "    docker logs -f nginx-proxy-acme"
echo ""
echo "  Verifica URL:"
echo "    curl -I https://${RETELL_BACKEND_SUBDOMAIN}"
echo ""
echo "  Restart servizio:"
echo "    docker restart retell-backend"
echo ""

print_status "Setup completato! Attendi 1-2 minuti per i certificati."
