#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SETUP NGINX-PROXY - Configurazione Flessibile della Rete  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

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

echo "[1/4] Arresto container precedenti..."
docker compose down 2>/dev/null || true
sleep 2

echo "[2/4] Avvio nginx-proxy..."
docker compose up -d nginx-proxy
sleep 5

echo "[3/4] Collegamento nginx-proxy alla rete '$NETWORK'..."
docker network connect "$NETWORK" nginx-proxy 2>/dev/null || true
sleep 2

echo "[4/4] Avvio acme-companion..."
docker compose up -d acme-companion
sleep 3
docker network connect "$NETWORK" nginx-proxy-acme 2>/dev/null || true

sleep 2

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

