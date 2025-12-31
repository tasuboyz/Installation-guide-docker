#!/bin/bash

# =============================================================================
# Nginx Reverse Proxy + SSL - SETUP COMPLETO AUTOMATIZZATO
# =============================================================================
# Questo script fa TUTTO in un'unica esecuzione:
# 1. Configura la rete Docker
# 2. Configura email Let's Encrypt  
# 3. Sceglie modalità SSL (staging/produzione)
# 4. Avvia nginx-proxy + acme-companion
# 5. CHIEDE quale container esporre
# 6. CHIEDE il sottodominio da usare
# 7. CHIEDE/rileva la porta
# 8. Genera configurazione per il container
# =============================================================================

set -euo pipefail

# Colors
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
# PREREQUISITI
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    print_error "Esegui con: sudo ./install.sh"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker non installato"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose non disponibile"
    exit 1
fi

clear
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     NGINX REVERSE PROXY + SSL AUTOMATICO                      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# STEP 1: RETE DOCKER
# =============================================================================

print_header "STEP 1/8 - Rete Docker"

# Carica .env esistente
DOCKER_NETWORK=""
LETSENCRYPT_EMAIL=""
ACME_CA_URI=""

if [[ -f .env ]]; then
    source .env 2>/dev/null || true
fi

echo "Reti Docker esistenti:"
docker network ls --format "  • {{.Name}}" | grep -v "bridge\|host\|none" || echo "  (nessuna)"
echo ""

if [[ -n "${DOCKER_NETWORK:-}" ]]; then
    echo "Rete attuale (da .env): ${DOCKER_NETWORK}"
    read -p "Usare questa rete? [Y/n]: " USE_NET
    USE_NET=${USE_NET:-y}
    [[ "${USE_NET,,}" != "y" ]] && DOCKER_NETWORK=""
fi

if [[ -z "$DOCKER_NETWORK" ]]; then
    read -p "Nome rete Docker [default: glpi-net]: " DOCKER_NETWORK
    DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}
fi

# Crea se non esiste
if ! docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK}$"; then
    print_warning "Rete '${DOCKER_NETWORK}' non esiste"
    read -p "Crearla? [Y/n]: " CREATE_NET
    CREATE_NET=${CREATE_NET:-y}
    if [[ "${CREATE_NET,,}" == "y" ]]; then
        docker network create "${DOCKER_NETWORK}"
        print_status "Rete creata"
    else
        print_error "Impossibile continuare"
        exit 1
    fi
else
    print_status "Rete '${DOCKER_NETWORK}' OK"
fi

# =============================================================================
# STEP 2: EMAIL
# =============================================================================

print_header "STEP 2/8 - Email Let's Encrypt"

if [[ -n "${LETSENCRYPT_EMAIL:-}" ]]; then
    echo "Email attuale: ${LETSENCRYPT_EMAIL}"
    read -p "Usare questa email? [Y/n]: " USE_EMAIL
    USE_EMAIL=${USE_EMAIL:-y}
    [[ "${USE_EMAIL,,}" != "y" ]] && LETSENCRYPT_EMAIL=""
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    read -p "Email per Let's Encrypt: " LETSENCRYPT_EMAIL
fi

if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Email non valida"
    exit 1
fi

print_status "Email: ${LETSENCRYPT_EMAIL}"

# =============================================================================
# STEP 3: MODALITÀ SSL
# =============================================================================

print_header "STEP 3/8 - Modalità SSL"

echo "  1) PRODUZIONE - certificati validi (limite: 5/settimana per dominio)"
echo "  2) STAGING    - certificati test (illimitati, per debug)"
echo ""
read -p "Scegli [1/2, default: 1]: " SSL_CHOICE
SSL_CHOICE=${SSL_CHOICE:-1}

if [[ "$SSL_CHOICE" == "2" ]]; then
    ACME_CA_URI="https://acme-staging-v02.api.letsencrypt.org/directory"
    print_warning "STAGING attivo - certificati NON validi per browser"
else
    ACME_CA_URI=""
    print_status "PRODUZIONE - certificati validi"
fi

# =============================================================================
# STEP 4: AVVIO PROXY
# =============================================================================

print_header "STEP 4/8 - Avvio Nginx Proxy"

# Genera .env
echo "# Auto-generated $(date)" > .env
echo "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}" >> .env
echo "DOCKER_NETWORK=${DOCKER_NETWORK}" >> .env
[[ -n "$ACME_CA_URI" ]] && echo "ACME_CA_URI=${ACME_CA_URI}" >> .env

print_status ".env generato"

# Stop se running
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    echo "Riavvio proxy..."
    docker compose down 2>/dev/null || true
fi

echo "Avvio container..."
docker compose up -d
sleep 3

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    print_status "nginx-proxy attivo"
else
    print_error "Errore avvio nginx-proxy"
    exit 1
fi

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    print_status "acme-companion attivo"
else
    print_error "Errore avvio acme-companion"
    exit 1
fi

# =============================================================================
# STEP 5: SELEZIONE CONTAINER
# =============================================================================

print_header "STEP 5/8 - Seleziona Container da Esporre"

CONTAINERS=$(docker ps --format '{{.Names}}' | grep -v "nginx-proxy" | sort)

if [[ -z "$CONTAINERS" ]]; then
    print_warning "Nessun container trovato (oltre a nginx-proxy)"
    echo ""
    echo "Avvia prima il servizio da esporre, poi riesegui:"
    echo "  sudo ./install.sh"
    exit 0
fi

echo "Container disponibili:"
echo ""
i=1
declare -A CMAP
while IFS= read -r c; do
    IMG=$(docker inspect "$c" --format='{{.Config.Image}}' 2>/dev/null | rev | cut -d/ -f1 | rev | cut -d: -f1)
    PTS=$(docker inspect "$c" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | tr -d '/tcpud' | xargs)
    printf "  %2d) %-25s [%s] ports: %s\n" "$i" "$c" "$IMG" "${PTS:-n/a}"
    CMAP[$i]="$c"
    ((i++))
done <<< "$CONTAINERS"

echo ""
read -p "Seleziona [1-$((i-1))]: " CCHOICE

if [[ -z "${CMAP[$CCHOICE]:-}" ]]; then
    print_error "Selezione non valida"
    exit 1
fi

CONTAINER_NAME="${CMAP[$CCHOICE]}"
print_status "Container: ${CONTAINER_NAME}"

# =============================================================================
# STEP 6: SOTTODOMINIO
# =============================================================================

print_header "STEP 6/8 - Sottodominio"

echo "Inserisci il sottodominio COMPLETO che vuoi usare per ${CONTAINER_NAME}"
echo ""
echo "Esempi:"
echo "  • n8n.tuodominio.com"
echo "  • chat.example.org"
echo "  • glpi.azienda.it"
echo ""
read -p "Sottodominio: " SUBDOMAIN

if [[ -z "$SUBDOMAIN" ]]; then
    print_error "Sottodominio obbligatorio"
    exit 1
fi

if [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*)?[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_error "Formato non valido: $SUBDOMAIN"
    exit 1
fi

print_status "Sottodominio: ${SUBDOMAIN}"

# Check DNS
if command -v dig &> /dev/null; then
    DNS=$(dig +short "$SUBDOMAIN" A 2>/dev/null || echo "")
    if [[ -n "$DNS" ]]; then
        print_status "DNS: $DNS"
    else
        print_warning "DNS non configurato - configuralo prima di richiedere il certificato"
    fi
fi

# =============================================================================
# STEP 7: PORTA
# =============================================================================

print_header "STEP 7/8 - Porta Interna"

PORTS=$(docker inspect "$CONTAINER_NAME" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | tr ' ' '\n' | sed 's|/.*||' | sort -nu | grep -v '^$' || echo "")

if [[ -n "$PORTS" ]]; then
    PARR=($PORTS)
    PCOUNT=${#PARR[@]}
    
    if [[ $PCOUNT -eq 1 ]]; then
        INTERNAL_PORT="${PARR[0]}"
        echo "Porta rilevata: ${INTERNAL_PORT}"
        read -p "Usare questa porta? [Y/n]: " USE_PORT
        USE_PORT=${USE_PORT:-y}
        if [[ "${USE_PORT,,}" != "y" ]]; then
            read -p "Inserisci porta: " INTERNAL_PORT
        fi
    else
        echo "Porte rilevate:"
        j=1
        declare -A PMAP
        for p in "${PARR[@]}"; do
            echo "  $j) $p"
            PMAP[$j]="$p"
            ((j++))
        done
        echo ""
        read -p "Seleziona [1-$((j-1))]: " PCHOICE
        INTERNAL_PORT="${PMAP[$PCHOICE]:-}"
        if [[ -z "$INTERNAL_PORT" ]]; then
            read -p "Porta non valida. Inserisci manualmente: " INTERNAL_PORT
        fi
    fi
else
    read -p "Nessuna porta rilevata. Inserisci porta: " INTERNAL_PORT
fi

if [[ -z "$INTERNAL_PORT" ]]; then
    print_error "Porta obbligatoria"
    exit 1
fi

print_status "Porta: ${INTERNAL_PORT}"

# =============================================================================
# STEP 8: RIEPILOGO E APPLICAZIONE
# =============================================================================

print_header "STEP 8/8 - Riepilogo"

echo ""
echo "  Container:     ${CONTAINER_NAME}"
echo "  Sottodominio:  ${SUBDOMAIN}"
echo "  Porta:         ${INTERNAL_PORT}"
echo "  Email:         ${LETSENCRYPT_EMAIL}"
echo "  Rete:          ${DOCKER_NETWORK}"
echo "  Modalità:      $(if [[ -n "$ACME_CA_URI" ]]; then echo 'STAGING (test)'; else echo 'PRODUZIONE'; fi)"
echo ""
read -p "Procedo con la configurazione? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [[ "${CONFIRM,,}" != "y" ]]; then
    echo "Annullato"
    exit 0
fi

echo ""
echo "Applicazione configurazione..."

# Connetti container alla rete se necessario
CNETS=$(docker inspect "$CONTAINER_NAME" --format='{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{end}}' 2>/dev/null)
if [[ ! "$CNETS" =~ $DOCKER_NETWORK ]]; then
    echo "Connessione a rete ${DOCKER_NETWORK}..."
    docker network connect "$DOCKER_NETWORK" "$CONTAINER_NAME" 2>/dev/null || true
fi

# Salva configurazione
CONFIG_FILE="configs/${CONTAINER_NAME}.conf"
mkdir -p configs
cat > "$CONFIG_FILE" << EOF
# Configurazione per ${CONTAINER_NAME}
# Generato: $(date)
CONTAINER=${CONTAINER_NAME}
SUBDOMAIN=${SUBDOMAIN}
PORT=${INTERNAL_PORT}
EMAIL=${LETSENCRYPT_EMAIL}
NETWORK=${DOCKER_NETWORK}
EOF

print_status "Config salvata: ${CONFIG_FILE}"

# =============================================================================
# OUTPUT FINALE
# =============================================================================

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║                    CONFIGURAZIONE COMPLETATA                  ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_warning "AZIONE RICHIESTA: Devi ricreare il container con le variabili proxy"
echo ""
echo "Se usi docker run, ricrea il container con:"
echo ""
echo -e "${CYAN}docker stop ${CONTAINER_NAME} && docker rm ${CONTAINER_NAME}${NC}"
echo -e "${CYAN}docker run -d --name ${CONTAINER_NAME} \\${NC}"
echo -e "${CYAN}  --network ${DOCKER_NETWORK} \\${NC}"
echo -e "${CYAN}  -e VIRTUAL_HOST=${SUBDOMAIN} \\${NC}"
echo -e "${CYAN}  -e VIRTUAL_PORT=${INTERNAL_PORT} \\${NC}"
echo -e "${CYAN}  -e LETSENCRYPT_HOST=${SUBDOMAIN} \\${NC}"
echo -e "${CYAN}  -e LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL} \\${NC}"
echo -e "${CYAN}  [altre opzioni originali] <immagine>${NC}"
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Se usi docker-compose, aggiungi al tuo docker-compose.yml:"
echo ""
cat << EOF
services:
  ${CONTAINER_NAME}:
    environment:
      - VIRTUAL_HOST=${SUBDOMAIN}
      - VIRTUAL_PORT=${INTERNAL_PORT}
      - LETSENCRYPT_HOST=${SUBDOMAIN}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

echo ""
echo "Poi: docker compose up -d"
echo ""
echo "─────────────────────────────────────────────────────────────────"

if [[ -n "$ACME_CA_URI" ]]; then
    echo ""
    print_warning "ATTENZIONE: Modalità STAGING - il certificato NON sarà valido"
fi

echo ""
echo "Verifica:"
echo "  docker logs nginx-proxy-acme -f     # Log certificati"
echo "  curl -I https://${SUBDOMAIN}        # Test (dopo DNS ok)"
echo ""

# Chiedi se configurare altro
read -p "Configurare un altro servizio? [y/N]: " ANOTHER
ANOTHER=${ANOTHER:-n}
if [[ "${ANOTHER,,}" == "y" ]]; then
    exec "$0"
fi

print_status "Setup completato!"
