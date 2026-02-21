#!/bin/bash

# OpenClaw Installation Script
# Installazione GUIDATA di OpenClaw AI Gateway via Docker
# Run with: sudo ./install.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${CYAN}[i]${NC} $1"; }

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

DOCKER_NETWORK=""
USE_PROXY=false
OPENCLAW_DOMAIN=""
LETSENCRYPT_EMAIL=""
OPENCLAW_PORT=18789
ENABLE_SANDBOX=false
SETUP_CHANNELS=false
OPENCLAW_HOME_VOLUME=""
OPENCLAW_DOCKER_APT_PACKAGES=""

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           OPENCLAW AI - INSTALLAZIONE GUIDATA                ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_prerequisites() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Questo script deve essere eseguito con privilegi root. Usa: sudo ./install.sh"
        exit 1
    fi

    if ! command -v docker &> /dev/null; then
        print_error "Docker non è installato. Installa Docker prima di continuare."
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose v2 non disponibile. Installalo prima di continuare."
        exit 1
    fi

    if ! command -v openssl &> /dev/null; then
        print_error "openssl non è installato. Necessario per generare il token."
        exit 1
    fi

    print_status "Prerequisiti verificati (Docker, Docker Compose v2, openssl)"
}

setup_network() {
    echo -e "${CYAN}STEP 1/7${NC} - Rete Docker"
    echo ""

    EXISTING_NETWORKS=$(docker network ls --format '{{.Name}}' | grep -v -E '^(bridge|host|none)$' || true)

    if [[ -n "$EXISTING_NETWORKS" ]]; then
        print_info "Reti Docker esistenti:"
        echo "$EXISTING_NETWORKS" | while read net; do echo "   - $net"; done
        echo ""
    fi

    read -p "Nome rete Docker [default: glpi-net]: " DOCKER_NETWORK
    DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}

    if ! docker network inspect "$DOCKER_NETWORK" &>/dev/null; then
        docker network create "$DOCKER_NETWORK"
        print_status "Rete '$DOCKER_NETWORK' creata"
    else
        print_status "Rete '$DOCKER_NETWORK' già esistente"
    fi
}

setup_domain() {
    echo ""
    echo -e "${CYAN}STEP 2/7${NC} - Configurazione Dominio (opzionale)"
    echo ""
    print_info "Se vuoi esporre OpenClaw con un sottodominio e SSL automatico,"
    print_info "inserisci il dominio qui. Altrimenti premi INVIO per accesso locale."
    echo ""

    read -p "Dominio (es. openclaw.example.com) [vuoto = solo locale]: " OPENCLAW_DOMAIN

    if [[ -n "$OPENCLAW_DOMAIN" ]]; then
        USE_PROXY=true

        print_info "Verifica DNS per $OPENCLAW_DOMAIN..."
        RESOLVED_IP=$(dig +short "$OPENCLAW_DOMAIN" 2>/dev/null | head -1)
        if [[ -n "$RESOLVED_IP" ]]; then
            print_status "DNS: $OPENCLAW_DOMAIN → $RESOLVED_IP"
        else
            print_warning "DNS non risolto per $OPENCLAW_DOMAIN"
            print_warning "Assicurati che il DNS sia configurato prima di procedere."
        fi

        echo ""
        echo -e "${CYAN}STEP 3/7${NC} - Email per Let's Encrypt"
        echo ""

        read -p "Email per certificati SSL: " LETSENCRYPT_EMAIL
        while [[ -z "$LETSENCRYPT_EMAIL" ]]; do
            print_error "Email obbligatoria per SSL"
            read -p "Email per certificati SSL: " LETSENCRYPT_EMAIL
        done

        print_status "Email: $LETSENCRYPT_EMAIL"
    else
        print_info "Installazione in modalità locale (porta $OPENCLAW_PORT)"
        echo ""
        echo -e "${CYAN}STEP 3/7${NC} - Saltato (nessun dominio)"
    fi
}

generate_token() {
    echo ""
    echo -e "${CYAN}STEP 4/7${NC} - Generazione token gateway"
    echo ""

    OPENCLAW_GATEWAY_TOKEN=$(openssl rand -hex 32)
    print_status "Token gateway generato"
}

configure_options() {
    echo ""
    echo -e "${CYAN}STEP 5/7${NC} - Opzioni avanzate"
    echo ""

    read -p "Vuoi persistere /home/node tra ricreazioni container? [y/N]: " persist_home
    if [[ "${persist_home,,}" == "y" ]]; then
        OPENCLAW_HOME_VOLUME="openclaw_home"
        print_status "Volume persistente: $OPENCLAW_HOME_VOLUME"
    fi

    read -p "Pacchetti apt aggiuntivi da installare nell'immagine? (spazio-separati, vuoto=nessuno): " apt_packages
    if [[ -n "$apt_packages" ]]; then
        OPENCLAW_DOCKER_APT_PACKAGES="$apt_packages"
        print_status "Pacchetti extra: $OPENCLAW_DOCKER_APT_PACKAGES"
    fi

    read -p "Vuoi abilitare il sandbox per gli agenti? [y/N]: " enable_sandbox
    if [[ "${enable_sandbox,,}" == "y" ]]; then
        ENABLE_SANDBOX=true
        print_status "Sandbox agenti abilitato"
    fi

    read -p "Vuoi configurare canali (Telegram/Discord/WhatsApp) dopo l'installazione? [y/N]: " channels
    if [[ "${channels,,}" == "y" ]]; then
        SETUP_CHANNELS=true
        print_status "Configurazione canali prevista dopo l'installazione"
    fi
}

write_env_file() {
    echo ""
    echo -e "${CYAN}STEP 6/7${NC} - Generazione configurazione"
    echo ""

    cat > .env << ENV_EOF
# OpenClaw Environment Configuration
# Generato da install.sh il $(date '+%Y-%m-%d %H:%M:%S')

# === Gateway ===
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
OPENCLAW_PORT=${OPENCLAW_PORT}
NODE_ENV=production
ENV_EOF

    if [[ -n "$OPENCLAW_HOME_VOLUME" ]]; then
        echo "" >> .env
        echo "# === Volume persistente ===" >> .env
        echo "OPENCLAW_HOME_VOLUME=${OPENCLAW_HOME_VOLUME}" >> .env
    fi

    if [[ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]]; then
        echo "" >> .env
        echo "# === Pacchetti extra ===" >> .env
        echo "OPENCLAW_DOCKER_APT_PACKAGES=${OPENCLAW_DOCKER_APT_PACKAGES}" >> .env
    fi

    if [[ "$USE_PROXY" == "true" ]]; then
        cat >> .env << ENV_EOF

# === Dominio e SSL ===
VIRTUAL_HOST=${OPENCLAW_DOMAIN}
VIRTUAL_PORT=18789
LETSENCRYPT_HOST=${OPENCLAW_DOMAIN}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
DOCKER_NETWORK=${DOCKER_NETWORK}
ENV_EOF
    else
        cat >> .env << ENV_EOF

# === Configurazione Locale ===
DOCKER_NETWORK=${DOCKER_NETWORK}
ENV_EOF
    fi

    print_status "File .env generato"
}

generate_compose() {
    cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  openclaw-gateway:
    image: openclaw:local
    build:
      context: .
      dockerfile: Dockerfile
    container_name: openclaw-gateway
    restart: unless-stopped
    env_file: .env
COMPOSE_EOF

    if [[ "$USE_PROXY" == "true" ]]; then
        cat >> docker-compose.yml << 'COMPOSE_EOF'
    expose:
      - "18789"
    environment:
      - NODE_ENV=production
      - VIRTUAL_HOST=${VIRTUAL_HOST}
      - VIRTUAL_PORT=18789
      - LETSENCRYPT_HOST=${LETSENCRYPT_HOST}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
COMPOSE_EOF
    else
        cat >> docker-compose.yml << 'COMPOSE_EOF'
    ports:
      - "${OPENCLAW_PORT:-18789}:18789"
    environment:
      - NODE_ENV=production
COMPOSE_EOF
    fi

    cat >> docker-compose.yml << 'COMPOSE_EOF'
    volumes:
      - openclaw_config:/home/node/.openclaw
      - openclaw_workspace:/home/node/.openclaw/workspace
COMPOSE_EOF

    if [[ -n "$OPENCLAW_HOME_VOLUME" ]]; then
        echo "      - ${OPENCLAW_HOME_VOLUME}:/home/node" >> docker-compose.yml
    fi

    cat >> docker-compose.yml << 'COMPOSE_EOF'
    healthcheck:
      test: ["CMD", "node", "dist/index.js", "health", "--token", "${OPENCLAW_GATEWAY_TOKEN}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - default
COMPOSE_EOF

    if [[ "$USE_PROXY" == "true" ]]; then
        cat >> docker-compose.yml << COMPOSE_EOF
      - ${DOCKER_NETWORK}
COMPOSE_EOF
    fi

    cat >> docker-compose.yml << 'COMPOSE_EOF'
    restart: always

  openclaw-cli:
    image: openclaw:local
    container_name: openclaw-cli
    env_file: .env
    volumes:
      - openclaw_config:/home/node/.openclaw
      - openclaw_workspace:/home/node/.openclaw/workspace
COMPOSE_EOF

    if [[ -n "$OPENCLAW_HOME_VOLUME" ]]; then
        echo "      - ${OPENCLAW_HOME_VOLUME}:/home/node" >> docker-compose.yml
    fi

    cat >> docker-compose.yml << 'COMPOSE_EOF'
    networks:
      - default
    profiles:
      - cli
    entrypoint: ["node", "dist/cli.js"]

volumes:
  openclaw_config:
  openclaw_workspace:
COMPOSE_EOF

    if [[ -n "$OPENCLAW_HOME_VOLUME" ]]; then
        echo "  ${OPENCLAW_HOME_VOLUME}:" >> docker-compose.yml
    fi

    cat >> docker-compose.yml << 'COMPOSE_EOF'

networks:
  default:
    driver: bridge
COMPOSE_EOF

    if [[ "$USE_PROXY" == "true" ]]; then
        cat >> docker-compose.yml << COMPOSE_EOF
  ${DOCKER_NETWORK}:
    external: true
COMPOSE_EOF
    fi

    print_status "docker-compose.yml generato"
}

build_and_start() {
    echo ""
    echo -e "${CYAN}STEP 7/7${NC} - Build e avvio servizi"
    echo ""

    print_info "Pulizia installazioni precedenti..."
    docker compose down -v 2>/dev/null || true

    print_info "Build immagine OpenClaw (potrebbe richiedere alcuni minuti)..."
    local build_args=""
    if [[ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]]; then
        build_args="--build-arg OPENCLAW_DOCKER_APT_PACKAGES=\"${OPENCLAW_DOCKER_APT_PACKAGES}\""
    fi
    docker compose build $build_args

    print_info "Esecuzione onboarding wizard..."
    docker compose run --rm openclaw-cli onboard

    print_info "Avvio OpenClaw gateway..."
    docker compose up -d openclaw-gateway

    sleep 5

    if docker compose ps | grep -q "openclaw-gateway.*running\|openclaw-gateway.*Up"; then
        print_status "OpenClaw gateway avviato con successo!"
    else
        print_warning "Verifica lo stato con: docker compose ps"
    fi
}

build_sandbox_image() {
    if [[ "$ENABLE_SANDBOX" != "true" ]]; then
        return
    fi

    echo ""
    print_info "Build immagine sandbox..."

    if [[ -f "scripts/sandbox-setup.sh" ]]; then
        bash scripts/sandbox-setup.sh
        print_status "Immagine sandbox openclaw-sandbox:bookworm-slim creata"
    else
        print_warning "Script sandbox-setup.sh non trovato."
        print_warning "Scaricalo dal repository OpenClaw e riesegui:"
        echo "   scripts/sandbox-setup.sh"
    fi
}

setup_channels() {
    if [[ "$SETUP_CHANNELS" != "true" ]]; then
        return
    fi

    echo ""
    print_info "Configurazione canali di comunicazione"
    echo ""
    echo "Seleziona i canali da configurare:"
    echo "  1) WhatsApp (QR code)"
    echo "  2) Telegram (bot token)"
    echo "  3) Discord (bot token)"
    echo "  4) Tutti"
    echo "  5) Nessuno (configura dopo)"
    echo ""

    read -p "Scelta [1-5]: " channel_choice

    case "$channel_choice" in
        1)
            print_info "Avvio login WhatsApp (scansiona il QR code)..."
            docker compose run --rm openclaw-cli channels login
            ;;
        2)
            read -p "Telegram Bot Token: " tg_token
            if [[ -n "$tg_token" ]]; then
                docker compose run --rm openclaw-cli channels add --channel telegram --token "$tg_token"
                print_status "Canale Telegram configurato"
            fi
            ;;
        3)
            read -p "Discord Bot Token: " dc_token
            if [[ -n "$dc_token" ]]; then
                docker compose run --rm openclaw-cli channels add --channel discord --token "$dc_token"
                print_status "Canale Discord configurato"
            fi
            ;;
        4)
            print_info "WhatsApp:"
            docker compose run --rm openclaw-cli channels login

            read -p "Telegram Bot Token (vuoto = salta): " tg_token
            if [[ -n "$tg_token" ]]; then
                docker compose run --rm openclaw-cli channels add --channel telegram --token "$tg_token"
            fi

            read -p "Discord Bot Token (vuoto = salta): " dc_token
            if [[ -n "$dc_token" ]]; then
                docker compose run --rm openclaw-cli channels add --channel discord --token "$dc_token"
            fi
            ;;
        *)
            print_info "Configurazione canali saltata. Puoi configurarli dopo con:"
            echo "   docker compose run --rm openclaw-cli channels login"
            echo "   docker compose run --rm openclaw-cli channels add --channel telegram --token <token>"
            ;;
    esac
}

print_summary() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              INSTALLAZIONE COMPLETATA                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ "$USE_PROXY" == "true" ]]; then
        echo -e "   ${GREEN}Dashboard:${NC}  https://$OPENCLAW_DOMAIN"
        echo -e "   ${GREEN}Email SSL:${NC}  $LETSENCRYPT_EMAIL"
    else
        echo -e "   ${GREEN}Dashboard:${NC}  http://localhost:${OPENCLAW_PORT}"
        echo -e "   ${GREEN}Accesso LAN:${NC} http://<IP_SERVER>:${OPENCLAW_PORT}"
    fi

    echo -e "   ${GREEN}Rete:${NC}       $DOCKER_NETWORK"
    echo -e "   ${GREEN}Token:${NC}      $OPENCLAW_GATEWAY_TOKEN"
    echo ""

    if [[ "$ENABLE_SANDBOX" == "true" ]]; then
        echo -e "   ${GREEN}Sandbox:${NC}    Abilitato (mode: non-main, scope: agent)"
    fi

    echo ""
    print_info "Apri la dashboard nel browser e incolla il token in Settings → Token."
    echo ""

    if [[ "$USE_PROXY" == "true" ]]; then
        print_info "Il certificato SSL verrà emesso automaticamente da acme-companion."
        print_warning "Assicurati che nginx-proxy e nginx-proxy-acme siano in esecuzione"
        print_warning "sulla stessa rete ($DOCKER_NETWORK)."
        echo ""
    fi

    echo "Comandi utili:"
    echo "   docker compose ps                                    # Stato servizi"
    echo "   docker compose logs -f openclaw-gateway              # Log gateway"
    echo "   docker compose run --rm openclaw-cli dashboard --no-open  # URL dashboard"
    echo "   docker compose run --rm openclaw-cli devices list    # Lista dispositivi"
    echo "   docker compose down                                  # Ferma tutto"
    echo "   ./diagnose.sh                                        # Diagnostica"
    echo ""
}

main() {
    check_prerequisites
    setup_network
    setup_domain
    generate_token
    configure_options
    write_env_file
    generate_compose
    build_and_start
    build_sandbox_image
    setup_channels
    print_summary
}

main "$@"
