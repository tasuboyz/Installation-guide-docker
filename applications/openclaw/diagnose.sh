#!/bin/bash

# OpenClaw Diagnostic Script
# Verifica stato e configurazione dell'installazione OpenClaw

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

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           OPENCLAW - DIAGNOSTICA                             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_files() {
    echo -e "${CYAN}=== File di configurazione ===${NC}"
    echo ""

    for file in .env docker-compose.yml Dockerfile; do
        if [[ -f "$file" ]]; then
            print_status "$file presente"
        else
            print_error "$file mancante"
        fi
    done
    echo ""
}

check_env() {
    echo -e "${CYAN}=== Variabili ambiente ===${NC}"
    echo ""

    if [[ ! -f .env ]]; then
        print_error "File .env non trovato"
        return
    fi

    source .env 2>/dev/null || true

    if [[ -n "$OPENCLAW_GATEWAY_TOKEN" ]]; then
        print_status "OPENCLAW_GATEWAY_TOKEN configurato (${OPENCLAW_GATEWAY_TOKEN:0:8}...)"
    else
        print_error "OPENCLAW_GATEWAY_TOKEN non configurato"
    fi

    if [[ -n "$OPENCLAW_PORT" ]]; then
        print_status "OPENCLAW_PORT=$OPENCLAW_PORT"
    else
        print_info "OPENCLAW_PORT non impostato (default: 18789)"
    fi

    if [[ -n "$VIRTUAL_HOST" ]]; then
        print_status "Modalità proxy: $VIRTUAL_HOST"
    else
        print_info "Modalità locale"
    fi
    echo ""
}

check_docker() {
    echo -e "${CYAN}=== Stato Docker ===${NC}"
    echo ""

    if ! command -v docker &>/dev/null; then
        print_error "Docker non installato"
        return
    fi
    print_status "Docker installato ($(docker --version | cut -d' ' -f3 | tr -d ','))"

    if docker compose version &>/dev/null; then
        print_status "Docker Compose v2 disponibile"
    else
        print_error "Docker Compose v2 non disponibile"
    fi
    echo ""
}

check_containers() {
    echo -e "${CYAN}=== Container ===${NC}"
    echo ""

    local gateway_status
    gateway_status=$(docker inspect --format='{{.State.Status}}' openclaw-gateway 2>/dev/null || echo "not_found")

    case "$gateway_status" in
        running)
            print_status "openclaw-gateway: $gateway_status"
            local uptime
            uptime=$(docker inspect --format='{{.State.StartedAt}}' openclaw-gateway 2>/dev/null)
            print_info "  Avviato: $uptime"
            ;;
        not_found)
            print_error "openclaw-gateway: container non trovato"
            ;;
        *)
            print_warning "openclaw-gateway: $gateway_status"
            ;;
    esac
    echo ""
}

check_image() {
    echo -e "${CYAN}=== Immagini Docker ===${NC}"
    echo ""

    if docker image inspect openclaw:local &>/dev/null; then
        local size
        size=$(docker image inspect openclaw:local --format='{{.Size}}' | awk '{printf "%.0f MB", $1/1024/1024}')
        print_status "openclaw:local presente ($size)"
    else
        print_error "openclaw:local non trovata (esegui: docker compose build)"
    fi

    if docker image inspect openclaw-sandbox:bookworm-slim &>/dev/null; then
        print_status "openclaw-sandbox:bookworm-slim presente"
    else
        print_info "openclaw-sandbox:bookworm-slim non presente (opzionale)"
    fi
    echo ""
}

check_network() {
    echo -e "${CYAN}=== Reti Docker ===${NC}"
    echo ""

    if [[ -f .env ]]; then
        source .env 2>/dev/null || true
    fi

    local network="${DOCKER_NETWORK:-glpi-net}"

    if docker network inspect "$network" &>/dev/null; then
        print_status "Rete '$network' presente"
        local containers
        containers=$(docker network inspect "$network" --format='{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)
        if [[ -n "$containers" ]]; then
            print_info "  Container connessi: $containers"
        fi
    else
        print_warning "Rete '$network' non trovata"
    fi
    echo ""
}

check_volumes() {
    echo -e "${CYAN}=== Volumi ===${NC}"
    echo ""

    for vol in openclaw_config openclaw_workspace; do
        local full_name
        full_name=$(docker volume ls --format '{{.Name}}' | grep -E "${vol}$" | head -1)
        if [[ -n "$full_name" ]]; then
            print_status "$full_name presente"
        else
            print_info "$vol non ancora creato"
        fi
    done
    echo ""
}

check_health() {
    echo -e "${CYAN}=== Health Check ===${NC}"
    echo ""

    local gateway_status
    gateway_status=$(docker inspect --format='{{.State.Status}}' openclaw-gateway 2>/dev/null || echo "not_found")

    if [[ "$gateway_status" != "running" ]]; then
        print_error "Gateway non in esecuzione, impossibile verificare health"
        return
    fi

    if [[ -f .env ]]; then
        source .env 2>/dev/null || true
    fi

    local port="${OPENCLAW_PORT:-18789}"

    if curl -sf "http://localhost:${port}/" &>/dev/null; then
        print_status "Gateway raggiungibile su porta $port"
    else
        print_warning "Gateway non raggiungibile su porta $port"
        print_info "Verifica i log con: docker compose logs openclaw-gateway"
    fi
    echo ""
}

check_logs() {
    echo -e "${CYAN}=== Ultimi log gateway ===${NC}"
    echo ""

    if docker inspect openclaw-gateway &>/dev/null; then
        docker logs --tail 15 openclaw-gateway 2>&1 || print_warning "Impossibile leggere i log"
    else
        print_info "Container non presente"
    fi
    echo ""
}

main() {
    check_files
    check_env
    check_docker
    check_containers
    check_image
    check_network
    check_volumes
    check_health
    check_logs

    echo -e "${CYAN}=== Riepilogo ===${NC}"
    echo ""
    echo "Per risolvere problemi comuni:"
    echo "   docker compose logs -f openclaw-gateway     # Log completi"
    echo "   docker compose restart openclaw-gateway     # Riavvia gateway"
    echo "   docker compose down && docker compose up -d # Ricrea container"
    echo "   docker compose build --no-cache             # Ricostruisci immagine"
    echo ""
}

main "$@"
