#!/bin/bash

# Nginx Reverse Proxy + Certbot SSL Installation Script
# This script sets up nginx-proxy with automatic SSL certificate management
# Run with: sudo ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with root privileges. Use: sudo ./install.sh"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

print_header "Nginx Reverse Proxy + SSL Installation"

echo ""
print_header "Configurazione Rete Docker"

# Show existing networks
print_status "Reti Docker esistenti:"
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -v "bridge\|host\|none" || echo "  (nessuna rete custom trovata)"

echo ""
read -p "Inserisci il nome della rete Docker da usare (default: glpi-net): " DOCKER_NETWORK

DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}

# Check if network exists
if ! docker network ls | grep -q "$DOCKER_NETWORK"; then
    print_warning "La rete '$DOCKER_NETWORK' non esiste."
    read -p "Vuoi crearla ora? (y/n): " CREATE_NET
    if [[ "$CREATE_NET" == "y" ]]; then
        docker network create "$DOCKER_NETWORK"
        print_status "Rete '$DOCKER_NETWORK' creata con successo"
    else
        print_error "Impossibile continuare senza una rete Docker"
        exit 1
    fi
else
    print_status "Rete '$DOCKER_NETWORK' già esistente"
fi

echo ""
print_header "Configurazione SSL"

# Get subdomain
read -p "Inserisci il sottodominio completo (es: n8n.example.com): " SUBDOMAIN

# Validate domain format
if [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Formato dominio non valido"
    exit 1
fi

# Extract email from subdomain (use domain part)
DOMAIN_PART=$(echo "$SUBDOMAIN" | awk -F. '{print $(NF-1)"."$NF}')
DEFAULT_EMAIL="admin@${DOMAIN_PART}"

# Get or generate email
if [[ -f .env ]]; then
    source .env
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    echo ""
    print_status "Email rilevata automaticamente: $DEFAULT_EMAIL"
    read -p "Premi INVIO per confermare o inserisci un'altra email: " CUSTOM_EMAIL
    
    if [[ -z "$CUSTOM_EMAIL" ]]; then
        LETSENCRYPT_EMAIL="$DEFAULT_EMAIL"
    else
        # Validate custom email format
        if [[ ! "$CUSTOM_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            print_error "Formato email non valido"
            exit 1
        fi
        LETSENCRYPT_EMAIL="$CUSTOM_EMAIL"
    fi
    
    print_status "Email configurata: $LETSENCRYPT_EMAIL"
fi

# Ask for staging mode
echo ""
print_status "Modalità certificati SSL:"
echo "  1) Produzione (certificati validi, limite 5/settimana)"
echo "  2) Staging (certificati test, illimitati - per debug)"
read -p "Scegli modalità [1/2] (default: 1): " SSL_MODE

SSL_MODE=${SSL_MODE:-1}

if [[ "$SSL_MODE" == "2" ]]; then
    ACME_CA_URI="https://acme-staging-v02.api.letsencrypt.org/directory"
    print_warning "Modalità STAGING attivata - i certificati NON saranno fidati dai browser"
    echo "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL" > .env
    echo "DOCKER_NETWORK=$DOCKER_NETWORK" >> .env
    echo "ACME_CA_URI=$ACME_CA_URI" >> .env
else
    print_status "Modalità PRODUZIONE attivata"
    echo "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL" > .env
    echo "DOCKER_NETWORK=$DOCKER_NETWORK" >> .env
fi

# Check if nginx-proxy is already running
if docker ps | grep -q "nginx-proxy"; then
    print_warning "nginx-proxy is already running"
    read -p "Do you want to restart it? (y/n): " RESTART
    if [[ "$RESTART" == "y" ]]; then
        docker compose down
    else
        print_status "Keeping existing nginx-proxy running"
        exit 0
    fi
fi

# Start nginx-proxy
print_status "Starting nginx-proxy and acme-companion..."
docker compose up -d

# Wait for containers to be healthy
print_status "Waiting for containers to start..."
sleep 5

# Check if containers are running
if docker ps | grep -q "nginx-proxy" && docker ps | grep -q "nginx-proxy-acme"; then
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
print_status "  - Rete Docker: $DOCKER_NETWORK"
echo ""
print_header "Configurazione Automatica per: $SUBDOMAIN"
echo ""
print_status "Per applicare questa configurazione al tuo servizio, aggiungi queste variabili"
print_status "al docker-compose.yml del servizio:"
echo ""
echo "services:"
echo "  il-tuo-servizio:"
echo "    environment:"
echo "      - VIRTUAL_HOST=$SUBDOMAIN"
echo "      - VIRTUAL_PORT=<porta_interna>  # es: 3000 per Chatwoot, 5678 per n8n"
echo "      - LETSENCRYPT_HOST=$SUBDOMAIN"
echo "      - LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL"
echo "    networks:"
echo "      - $DOCKER_NETWORK"
echo "    expose:"
echo "      - \"<porta_interna>\""
echo ""
echo "networks:"
echo "  $DOCKER_NETWORK:"
echo "    external: true"
echo ""
if [[ "$SSL_MODE" == "2" ]]; then
    print_warning "ATTENZIONE: Modalità STAGING - certificato non fidato"
    print_warning "Per produzione, riesegui lo script e scegli modalità 1"
fi
echo ""
print_status "Verifica DNS: nslookup $SUBDOMAIN"
print_status "Check logs: docker compose logs -f"
print_status "Certificati: docker exec nginx-proxy-acme ls -la /etc/nginx/certs/"
