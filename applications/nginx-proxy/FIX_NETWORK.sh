#!/bin/bash

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  FIX NETWORK SEMPLIFICATO - Collegamento reti Docker         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -f ".env" ]]; then
    echo "❌ ERRORE: .env non trovato"
    echo "   Esegui prima: sudo ./install.sh"
    exit 1
fi

source .env

NETWORK="${DOCKER_NETWORK:-n8n-net}"

echo "📌 Rete rilevata: $NETWORK"
echo ""

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "❌ ERRORE: Rete '$NETWORK' non esiste"
    echo "   Reti disponibili:"
    docker network ls
    exit 1
fi

echo "🔧 Operazioni:"
echo "  1. Fermarsi container nginx-proxy"
echo "  2. Connessione container nginx-proxy alla rete '$NETWORK'"
echo "  3. Riavvio container"
echo ""

read -p "Procedere? [Y/n]: " -r
echo ""

if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo "Annullato"
    exit 0
fi

echo "[1/3] Fermata container..."
docker compose down 2>/dev/null || true
sleep 3

echo "[2/3] Aggiunta nginx-proxy alla rete '$NETWORK'..."
docker compose up -d
sleep 5

echo "[3/3] Connessione della rete..."

if docker network inspect "$NETWORK" | grep -q "nginx-proxy"; then
    echo "     ✓ nginx-proxy già collegato a $NETWORK"
else
    docker network connect "$NETWORK" nginx-proxy 2>/dev/null || echo "     ℹ Container potrebbe non essere in esecuzione"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STATO"
echo "═══════════════════════════════════════════════════════════════"
echo ""

sleep 2

if docker ps | grep -q "nginx-proxy.*Up"; then
    echo "✅ nginx-proxy: ONLINE"
    NGINX_UP=1
else
    echo "❌ nginx-proxy: OFFLINE"
    NGINX_UP=0
fi

if docker ps | grep -q "nginx-proxy-acme.*Up"; then
    echo "✅ acme-companion: ONLINE"
else
    echo "❌ acme-companion: OFFLINE"
fi

echo ""

if [[ $NGINX_UP -eq 0 ]]; then
    echo "⚠️  nginx-proxy non è online. Controllare i log:"
    echo ""
    echo "  docker logs nginx-proxy | tail -50"
    echo ""
    exit 1
fi

echo "✅ Connessione verificata!"
echo ""
echo "Test connettività:"
echo ""
echo "  # Verificare che nginx-proxy è sulla rete corretta:"
echo "  docker network inspect $NETWORK | grep nginx-proxy -A 5"
echo ""
echo "  # Testare l'API di Chatwoot:"
echo "  curl --request GET \\"
echo "    --url 'https://chatwoot.tasuthor.com/api/v1/accounts/1/contacts?page=1' \\"
echo "    --header 'Authorization: Bearer bXY5ozTo3ArMtUZgbudtrqRA'"
echo ""
