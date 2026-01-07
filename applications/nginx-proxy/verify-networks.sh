#!/bin/bash

# Script di verifica reti e connettività nginx-proxy
# Usa questo script per diagnosticare problemi di rete

set -euo pipefail

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  NGINX-PROXY NETWORK DIAGNOSTICS                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

print_section "1. STATO CONTAINER NGINX-PROXY"

if docker ps -a --filter "name=nginx-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "nginx-proxy"; then
    docker ps -a --filter "name=nginx-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    NGINX_RUNNING=$(docker inspect --format='{{.State.Running}}' nginx-proxy 2>/dev/null || echo "false")
    NGINX_HEALTH=$(docker inspect --format='{{.State.Health.Status}}' nginx-proxy 2>/dev/null || echo "no healthcheck")
    
    echo ""
    if [[ "$NGINX_RUNNING" == "true" ]]; then
        echo -e "${GREEN}✓${NC} Container: Running"
    else
        echo -e "${RED}✗${NC} Container: Not Running"
    fi
    
    if [[ "$NGINX_HEALTH" == "healthy" ]]; then
        echo -e "${GREEN}✓${NC} Health: $NGINX_HEALTH"
    elif [[ "$NGINX_HEALTH" == "unhealthy" ]]; then
        echo -e "${RED}✗${NC} Health: $NGINX_HEALTH"
    else
        echo -e "${YELLOW}⚠${NC} Health: $NGINX_HEALTH"
    fi
else
    echo -e "${RED}✗${NC} Container nginx-proxy non trovato"
    exit 1
fi

print_section "2. RETI CONNESSE A NGINX-PROXY"

NGINX_NETWORKS=$(docker inspect nginx-proxy --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")

if [[ -n "$NGINX_NETWORKS" ]]; then
    echo "Reti connesse:"
    for net in $NGINX_NETWORKS; do
        echo -e "  ${GREEN}✓${NC} $net"
    done
else
    echo -e "${RED}✗${NC} Nessuna rete connessa"
fi

print_section "3. TUTTE LE RETI DOCKER CON CONTAINER ATTIVI"

echo "Reti con container attivi (escluse bridge/host/none):"
echo ""

declare -A network_containers

for container in $(docker ps --format '{{.Names}}'); do
    container_networks=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null || true)
    for net in $container_networks; do
        if [[ "$net" != "bridge" ]] && [[ "$net" != "host" ]] && [[ "$net" != "none" ]]; then
            if [[ -z "${network_containers[$net]:-}" ]]; then
                network_containers[$net]="$container"
            else
                network_containers[$net]="${network_containers[$net]}, $container"
            fi
        fi
    done
done

for net in "${!network_containers[@]}"; do
    if echo "$NGINX_NETWORKS" | grep -qw "$net"; then
        echo -e "${GREEN}✓${NC} $net"
    else
        echo -e "${YELLOW}⚠${NC} $net (nginx-proxy NON connesso)"
    fi
    echo "    Container: ${network_containers[$net]}"
    echo ""
done

print_section "4. VERIFICA CONNETTIVITÀ UPSTREAM"

echo "Test upstream backends generati da dockergen:"
echo ""

if docker exec nginx-proxy test -f /etc/nginx/conf.d/default.conf 2>/dev/null; then
    # Estrai nomi upstream
    UPSTREAMS=$(docker exec nginx-proxy grep -E "^upstream" /etc/nginx/conf.d/default.conf 2>/dev/null | awk '{print $2}' | sed 's/{//g' || true)
    
    if [[ -n "$UPSTREAMS" ]]; then
        for upstream in $UPSTREAMS; do
            # Verifica se ci sono server definiti
            SERVER_COUNT=$(docker exec nginx-proxy grep -A 10 "^upstream $upstream" /etc/nginx/conf.d/default.conf 2>/dev/null | grep -c "server " || echo "0")
            
            if [[ "$SERVER_COUNT" -gt 0 ]]; then
                echo -e "${GREEN}✓${NC} $upstream: $SERVER_COUNT server(s)"
            else
                echo -e "${RED}✗${NC} $upstream: NESSUN server (upstream vuoto)"
            fi
        done
    else
        echo -e "${YELLOW}⚠${NC} Nessun upstream trovato in default.conf"
    fi
else
    echo -e "${RED}✗${NC} Impossibile leggere /etc/nginx/conf.d/default.conf"
fi

print_section "5. ULTIMI LOG NGINX-PROXY"

docker logs nginx-proxy --tail 20 --timestamps

print_section "6. SUGGERIMENTI"

echo "Se nginx-proxy non è connesso a tutte le reti necessarie:"
echo ""
echo "  Connetti manualmente:"
for net in "${!network_containers[@]}"; do
    if ! echo "$NGINX_NETWORKS" | grep -qw "$net"; then
        echo "    docker network connect $net nginx-proxy"
    fi
done
echo ""
echo "  Oppure esegui:"
echo "    ./setup.sh"
echo ""
echo "Se il container è in restart loop:"
echo "  1. Verifica healthcheck:"
echo "     docker inspect nginx-proxy --format='{{json .State.Health}}' | jq ."
echo ""
echo "  2. Aumenta i timeout in docker-compose.yml:"
echo "     start_period: 40s"
echo "     timeout: 10s"
echo ""
echo "  3. Riavvia:"
echo "     docker compose restart nginx-proxy"
echo ""
