#!/bin/bash

# Nginx Reverse Proxy + Certbot SSL Installation Script
# Automated setup with CLI flags and non-interactive mode
# Usage: sudo ./install.sh [--email <mail>] [--network <name>] [--staging] [--yes]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

usage() {
    cat <<EOF
Usage: sudo ./install.sh [options]

Options:
  --email, -e <email>      Contact email for Let's Encrypt (required)
  --network, -n <name>     Docker network to use/create (default: glpi-net)
  --staging                Use Let's Encrypt staging (test certificates)
  --production             Use production certificates (default)
  --yes, -y                Non-interactive mode
  --help, -h               Show this help

Example:
  sudo ./install.sh --email admin@example.com --yes
  sudo ./install.sh --email admin@example.com --staging --yes
EOF
}

# Parse CLI args
DOCKER_NETWORK=""
SSL_MODE=1
AUTO_CONFIRM=0
LETSENCRYPT_EMAIL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --email|-e) LETSENCRYPT_EMAIL="$2"; shift 2;;
        --network|-n) DOCKER_NETWORK="$2"; shift 2;;
        --staging) SSL_MODE=2; shift;;
        --production) SSL_MODE=1; shift;;
        --yes|-y) AUTO_CONFIRM=1; shift;;
        --help|-h) usage; exit 0;;
        *) print_error "Unknown option: $1"; usage; exit 1;;
    esac
done

# Ensure root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with root privileges. Use: sudo ./install.sh"
    exit 1
fi

# Check Docker availability
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

print_header "Nginx Reverse Proxy + SSL Installation"

echo ""
print_header "Configurazione Rete Docker"

# Load existing .env if present so user settings (like DOCKER_NETWORK) are respected
if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env || true
fi

# If network not provided via CLI or .env, ask user (or require in non-interactive)
if [[ -z "${DOCKER_NETWORK:-}" ]]; then
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_error "--network required in non-interactive mode"
        exit 1
    fi
    read -p "Inserisci il nome della rete Docker da usare (default: glpi-net): " DOCKER_NETWORK
    DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}
fi

print_status "Reti Docker esistenti:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -v "bridge\|host\|none" || echo "  (nessuna rete custom trovata)"

# Create/check network
if ! docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK}$"; then
    print_warning "La rete '${DOCKER_NETWORK}' non esiste."
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_status "Creazione automatica rete: ${DOCKER_NETWORK}"
        docker network create "${DOCKER_NETWORK}"
    else
        read -p "Vuoi crearla ora? (y/n): " CREATE_NET
        if [[ "$CREATE_NET" == "y" ]]; then
            docker network create "${DOCKER_NETWORK}"
            print_status "Rete '${DOCKER_NETWORK}' creata con successo"
        else
            print_error "Impossibile continuare senza una rete Docker"
            exit 1
        fi
    fi
else
    print_status "Rete '${DOCKER_NETWORK}' già esistente"
fi

echo ""
print_header "Configurazione Email Let's Encrypt"

# Get email if not provided
if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_error "--email required in non-interactive mode"
        exit 1
    fi
    read -p "Inserisci email per Let's Encrypt (notifiche scadenza certificati): " LETSENCRYPT_EMAIL
fi

# Validate email
if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Formato email non valido: $LETSENCRYPT_EMAIL"
    exit 1
fi

print_status "Email configurata: ${LETSENCRYPT_EMAIL}"

# SSL mode: ask interactively if not set via flag
if [[ $AUTO_CONFIRM -eq 0 ]]; then
    echo ""
    print_status "Modalità certificati SSL:"
    echo "  1) Produzione (certificati validi, limite 5/settimana per dominio)"
    echo "  2) Staging (certificati test, illimitati - per debug)"
    read -p "Scegli modalità [1/2] (default: 1): " SSL_CHOICE
    SSL_CHOICE=${SSL_CHOICE:-1}
    if [[ "$SSL_CHOICE" == "2" ]]; then SSL_MODE=2; fi
fi

if [[ "$SSL_MODE" == "2" ]]; then
    ACME_CA_URI="https://acme-staging-v02.api.letsencrypt.org/directory"
    print_warning "Modalità STAGING attivata - i certificati NON saranno fidati dai browser"
else
    ACME_CA_URI=""
    print_status "Modalità PRODUZIONE attivata"
fi

# Write .env
print_status "Generazione .env..."
{
    echo "# Auto-generated by install.sh - $(date)"
    echo "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}"
    echo "DOCKER_NETWORK=${DOCKER_NETWORK}"
    if [[ -n "$ACME_CA_URI" ]]; then 
        echo "ACME_CA_URI=${ACME_CA_URI}"
    fi
} > .env

print_status ".env generato con successo"

# Check if nginx-proxy is already running
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    print_warning "nginx-proxy is already running"
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_status "Riavvio automatico dei servizi per applicare le nuove impostazioni"
        docker compose down || true
    else
        read -p "Do you want to restart it? (y/n): " RESTART
        if [[ "$RESTART" == "y" ]]; then
            docker compose down
        else
            print_status "Keeping existing nginx-proxy running"
            exit 0
        fi
    fi
fi

print_status "Starting nginx-proxy and acme-companion..."
docker compose up -d

print_status "Waiting for containers to start..."
sleep 5

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy" && docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    print_status "✓ nginx-proxy is running"
    print_status "✓ acme-companion is running"
else
    print_error "Failed to start one or more containers"
    docker compose logs
    exit 1
fi

print_header "Installazione Completata!"
echo ""
print_status "Nginx reverse proxy attivo su:"
print_status "  - HTTP:  porta 80"
print_status "  - HTTPS: porta 443"
print_status "  - Rete Docker: ${DOCKER_NETWORK}"
print_status "  - Modalità SSL: $(if [[ $SSL_MODE -eq 2 ]]; then echo 'STAGING'; else echo 'PRODUZIONE'; fi)"
echo ""

print_header "Prossimo Passo: Configura i tuoi servizi"
echo ""
print_status "Per ogni servizio che vuoi esporre con SSL, esegui:"
echo ""
echo "  sudo ./setup-subdomain.sh"
echo ""
print_status "Oppure in modalità automatica:"
echo ""
echo "  sudo ./setup-subdomain.sh --subdomain n8n.example.com --container n8n --yes"
echo ""

if [[ "$SSL_MODE" == "2" ]]; then
    echo ""
    print_warning "ATTENZIONE: Modalità STAGING attiva"
    print_warning "I certificati NON saranno fidati dai browser"
    print_warning "Per produzione: sudo ./install.sh --email ${LETSENCRYPT_EMAIL} --production --yes"
fi

echo ""
print_status "Comandi utili:"
echo "  docker compose logs -f              # Log proxy + acme"
echo "  docker exec nginx-proxy nginx -t    # Test config nginx"
