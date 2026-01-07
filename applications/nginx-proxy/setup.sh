#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DEFAULT_CUSTOM_NGINX_CONF='client_max_body_size 100M;

proxy_buffer_size 128k;
proxy_buffers 4 256k;
proxy_busy_buffers_size 256k;

proxy_connect_timeout 600s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
'

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SETUP NGINX-PROXY - Configurazione Flessibile della Rete  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

ensure_custom_nginx_conf() {
    local conf_file="$SCRIPT_DIR/custom-nginx.conf"
    
    if [[ -d "$conf_file" ]]; then
        echo "⚠️  custom-nginx.conf è una directory (errore). Rimozione..."
        rm -rf "$conf_file"
    fi
    
    if [[ ! -f "$conf_file" ]]; then
        echo "📝 Creazione custom-nginx.conf con configurazione di default..."
        echo "$DEFAULT_CUSTOM_NGINX_CONF" > "$conf_file"
        echo "✅ custom-nginx.conf creato"
    fi
}

scan_active_networks() {
    local networks=()
    local containers=$(docker ps --format '{{.Names}}')
    
    for container in $containers; do
        local container_networks=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$container" 2>/dev/null || true)
        for net in $container_networks; do
            # Escludi reti di sistema
            if [[ "$net" != "bridge" ]] && [[ "$net" != "host" ]] && [[ "$net" != "none" ]]; then
                # Aggiungi solo se non già presente
                if [[ ! " ${networks[@]} " =~ " ${net} " ]]; then
                    networks+=("$net")
                fi
            fi
        done
    done
    
    printf '%s\n' "${networks[@]}"
}

connect_to_networks() {
    local container=$1
    shift
    local networks=("$@")
    
    echo "🔗 Connessione $container alle reti rilevanti..."
    
    for network in "${networks[@]}"; do
        # Verifica se già connesso
        if docker inspect "$container" --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null | grep -qw "$network"; then
            echo "   ✓ Già connesso a: $network"
        else
            echo "   → Connessione a: $network"
            if docker network connect "$network" "$container" 2>/dev/null; then
                echo "   ✅ Connesso a: $network"
            else
                echo "   ⚠️  Impossibile connettersi a: $network"
            fi
        fi
    done
}

wait_for_healthy() {
    local container=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    echo "⏳ Attesa che $container sia in running..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local status=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
        
        if [[ "$status" == "true" ]]; then
            echo "✅ $container è in running"
            return 0
        fi
        
        sleep 2
        ((attempt++))
    done
    
    echo "❌ Timeout: $container non è in running"
    return 1
}

if [[ ! -f ".env" ]]; then
    echo "⚠️  File .env non trovato. Creazione da .env.example..."
    
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
        echo "✅ .env creato. Modifica i valori e esegui di nuovo lo script."
        echo ""
        echo "File .env:"
        cat .env
        echo ""
        exit 0
    else
        cat > .env << 'EOF'
LETSENCRYPT_EMAIL=your-email@example.com
DOCKER_NETWORK=n8n-net
EOF
        echo "✅ .env creato con valori di default"
        echo ""
        echo "⚠️  IMPORTANTE: Edita il file .env e inserisci:"
        echo "   - LETSENCRYPT_EMAIL: la tua email per Let's Encrypt"
        echo "   - DOCKER_NETWORK: la rete Docker dove gira chatwoot/n8n/etc"
        echo ""
        exit 1
    fi
fi

source .env

NETWORK="${DOCKER_NETWORK:-n8n-net}"
EMAIL="${LETSENCRYPT_EMAIL}"

echo "📋 Configurazione:"
echo "   Email: $EMAIL"
echo "   Rete Docker: $NETWORK"
echo ""

if [[ -z "$EMAIL" ]] || [[ "$EMAIL" == "your-email@example.com" ]]; then
    echo "❌ ERRORE: Email non configurata nel .env"
    echo "   Modifica LETSENCRYPT_EMAIL in .env"
    exit 1
fi

if [[ -z "$NETWORK" ]]; then
    echo "❌ ERRORE: DOCKER_NETWORK non configurato nel .env"
    echo "   Modifica DOCKER_NETWORK in .env"
    exit 1
fi

echo "🔍 Verifica della rete Docker..."
echo ""

if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "✅ Rete '$NETWORK' trovata"
else
    echo "⚠️  Rete '$NETWORK' non esiste"
    echo ""
    echo "Reti Docker disponibili:"
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
    echo ""
    echo "Opzioni:"
    echo "  1. Creare una nuova rete: docker network create $NETWORK"
    echo "  2. Usare una rete esistente: edita DOCKER_NETWORK in .env"
    echo ""
    read -p "Creare la rete '$NETWORK'? [Y/n]: " -r
    echo ""
    
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
        echo "Creazione rete '$NETWORK'..."
        docker network create "$NETWORK"
        echo "✅ Rete '$NETWORK' creata"
    else
        echo "Annullato"
        exit 1
    fi
fi

ensure_custom_nginx_conf

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  AVVIO NGINX-PROXY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

read -p "Avviare nginx-proxy? [Y/n]: " -r
echo ""

if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo "Annullato"
    exit 0
fi

echo "[1/5] Arresto container precedenti..."
docker compose down 2>/dev/null || true
sleep 2

echo "[2/5] Scansione reti Docker..."
echo "🔍 Scansione reti Docker con container attivi..."
readarray -t ACTIVE_NETWORKS < <(scan_active_networks)
if [ ${#ACTIVE_NETWORKS[@]} -gt 0 ]; then
    echo "   Reti rilevate: ${ACTIVE_NETWORKS[*]}"
else
    echo "   Nessuna rete con container attivi (oltre alla rete principale)"
fi

echo "[3/5] Avvio servizi con rete esterna '$NETWORK'..."
docker compose -f docker-compose.yml -f docker-compose.external-network.yml up -d

echo "[4/5] Connessione a reti aggiuntive..."
if [ ${#ACTIVE_NETWORKS[@]} -gt 0 ]; then
    sleep 3
    connect_to_networks "nginx-proxy" "${ACTIVE_NETWORKS[@]}"
    sleep 2
fi

echo "[5/5] Verifica stato..."

if ! wait_for_healthy "nginx-proxy"; then
    echo ""
    echo "❌ nginx-proxy non è partito correttamente"
    echo ""
    echo "Diagnostica:"
    docker logs nginx-proxy --tail 30
    echo ""
    echo "Reti del container:"
    docker inspect nginx-proxy --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
    exit 1
fi

sleep 3

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STATO"
echo "═══════════════════════════════════════════════════════════════"
echo ""

NGINX_STATUS=$(docker ps --filter "name=nginx-proxy" --format "{{.Status}}" | head -1)
ACME_STATUS=$(docker ps --filter "name=nginx-proxy-acme" --format "{{.Status}}" | head -1)

if [[ "$NGINX_STATUS" == *"Up"* ]]; then
    echo "✅ nginx-proxy: $NGINX_STATUS"
    NGINX_OK=1
else
    echo "❌ nginx-proxy: not running"
    NGINX_OK=0
fi

if [[ "$ACME_STATUS" == *"Up"* ]]; then
    echo "✅ acme-companion: $ACME_STATUS"
else
    echo "⚠️  acme-companion: $ACME_STATUS"
fi

echo ""

if [[ $NGINX_OK -eq 1 ]]; then
    echo "✅ nginx-proxy è online!"
    echo ""
    echo "📌 Prossimi passi:"
    echo ""
    echo "1. Configura i servizi con ./add-service.sh:"
    echo "   sudo ./add-service.sh"
    echo ""
    echo "2. Oppure in batch mode:"
    echo "   sudo ./add-service.sh --batch --base example.com"
    echo ""
    echo "3. Verifica i servizi configurati:"
    echo "   ./add-service.sh --list"
    echo ""
    echo "📚 Documentazione:"
    echo "   - README.md: Overview e comandi principali"
    echo "   - QUICK_START.md: Guide rapide"
    echo ""
else
    echo "❌ Errore nell'avvio di nginx-proxy"
    echo ""
    echo "Diagnostica:"
    echo "  docker logs -f nginx-proxy"
    echo ""
    exit 1
fi
