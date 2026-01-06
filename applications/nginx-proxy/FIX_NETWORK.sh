#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  FIX NETWORK - Collegamento nginx-proxy agli altri servizi   ║"
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

if ! docker network ls | grep -q "^${NETWORK}"; then
    echo "❌ ERRORE: Rete '$NETWORK' non esiste"
    echo "   Reti disponibili:"
    docker network ls
    exit 1
fi

echo "🔧 Operazioni:"
echo "  1. Fermarsi container nginx-proxy e acme-companion"
echo "  2. Aggiornamento configurazione docker-compose.yml"
echo "  3. Connessione di nginx-proxy alla rete '$NETWORK'"
echo "  4. Riavvio container"
echo ""

read -p "Procedere? [Y/n]: " -r
echo ""

if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo "Annullato"
    exit 0
fi

echo "[1/4] Fermata container..."
docker compose down 2>/dev/null || true
sleep 2

echo "[2/4] Aggiornamento docker-compose.yml..."

BACKUP_FILE="docker-compose.yml.backup.$(date +%s)"
cp docker-compose.yml "$BACKUP_FILE"
echo "     Backup: $BACKUP_FILE"

cat > docker-compose.yml << 'DOCKERCOMPOSE'
services:
  nginx-proxy:
    image: nginxproxy/nginx-proxy:latest
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - nginx-certs:/etc/nginx/certs
      - nginx-vhost:/etc/nginx/vhost.d
      - nginx-html:/usr/share/nginx/html
    environment:
      - TRUST_DOWNSTREAM_PROXY=false
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy=true"
    networks:
      - proxy-network
      - external-network
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  acme-companion:
    image: nginxproxy/acme-companion:latest
    container_name: nginx-proxy-acme
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - nginx-certs:/etc/nginx/certs:rw
      - nginx-vhost:/etc/nginx/vhost.d
      - nginx-html:/usr/share/nginx/html
      - acme-state:/etc/acme.sh
    environment:
      - DEFAULT_EMAIL=${LETSENCRYPT_EMAIL}
      - NGINX_PROXY_CONTAINER=nginx-proxy
      - NGINX_DOCKER_GEN_CONTAINER=nginx-proxy
      - ACME_CA_URI=${ACME_CA_URI:-}
    depends_on:
      - nginx-proxy
    networks:
      - proxy-network
      - external-network
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  proxy-network:
    driver: bridge
  external-network:
    name: ${DOCKER_NETWORK}
    external: true

volumes:
  nginx-certs:
  nginx-vhost:
  nginx-html:
  acme-state:
DOCKERCOMPOSE

echo "     ✓ docker-compose.yml aggiornato"
echo ""

echo "[3/4] Connessione rete '$NETWORK'..."
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "     ✓ Rete '$NETWORK' disponibile"
else
    echo "❌ ERRORE: Rete '$NETWORK' non trovata"
    exit 1
fi
echo ""

echo "[4/4] Riavvio container..."
docker compose up -d
sleep 5

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  STATO"
echo "═══════════════════════════════════════════════════════════════"
echo ""

if docker ps | grep -q "nginx-proxy.*Up"; then
    echo "✅ nginx-proxy: ONLINE"
else
    echo "❌ nginx-proxy: OFFLINE"
fi

if docker ps | grep -q "nginx-proxy-acme.*Up"; then
    echo "✅ acme-companion: ONLINE"
else
    echo "❌ acme-companion: OFFLINE"
fi

echo ""
echo "Test connettività:"
echo ""
echo "Per testare l'API di Chatwoot:"
echo "  curl --request GET \\"
echo "    --url 'https://chatwoot.tasuthor.com/api/v1/accounts/1/contacts?page=1' \\"
echo "    --header 'Authorization: Bearer bXY5ozTo3ArMtUZgbudtrqRA'"
echo ""
echo "Log di diagnostica:"
echo "  docker logs -f nginx-proxy"
echo ""

