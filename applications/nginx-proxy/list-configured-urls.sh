#!/bin/bash
# =============================================================================
# SCRIPT: Recupera URLs Configurati
# Descrizione: Visualizza rapidamente tutti i domini configurati su nginx-proxy
# Uso: ./list-configured-urls.sh
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}           DOMINI CONFIGURATI SU NGINX-PROXY${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Controlla se nginx-proxy è attivo
if ! docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    echo -e "${YELLOW}⚠  nginx-proxy non sembra attivo${NC}"
    echo ""
fi

echo -e "${BOLD}SERVIZI ESPOSTI (da .env.domains):${NC}"
echo ""

if [[ -f ".env.domains" ]]; then
    while IFS='=' read -r key value; do
        # Skip commenti e linee vuote
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue
        
        # Formatta output
        if [[ "$key" == *"SUBDOMAIN"* ]]; then
            SERVICE=$(echo "$key" | sed 's/_SUBDOMAIN.*//' | sed 's/_/ /g')
            printf "  %-20s %s\n" "$(echo $SERVICE | head -c 20)" "https://$value"
        fi
    done < .env.domains
else
    echo -e "${YELLOW}ℹ  .env.domains non trovato${NC}"
    echo "   Esegui: ./setup-domains.sh"
fi

echo ""
echo -e "${BOLD}CONTAINER ESPOSTI (da Docker):${NC}"
echo ""

# Leggi tutti i container con VIRTUAL_HOST
docker ps --format '{{.Names}}' | while read container; do
    VHOST=$(docker inspect "$container" --format='{{range .Config.Env}}{{if eq . (split (index (split . "=") 0) "VIRTUAL_HOST")}}{{. "=" ""}}{{end}}{{end}}' 2>/dev/null || echo "")
    
    if [[ -z "$VHOST" ]]; then
        VHOST=$(docker inspect "$container" --format='{{range .Config.Env}}{{if contains . "VIRTUAL_HOST="}}{{. "=" ""}}{{end}}{{end}}' 2>/dev/null || echo "")
    fi
    
    if [[ -n "$VHOST" ]]; then
        VPORT=$(docker inspect "$container" --format='{{range .Config.Env}}{{if contains . "VIRTUAL_PORT="}}{{. "=" ""}}{{end}}{{end}}' 2>/dev/null || echo "default")
        printf "  %-25s ${GREEN}https://%s${NC}\n" "$container" "$VHOST"
    fi
done

echo ""
echo -e "${BOLD}CERTIFICATI SSL (da Let's Encrypt):${NC}"
echo ""

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    docker exec nginx-proxy-acme ls -1 /etc/acme.sh/ 2>/dev/null | while read domain; do
        if [[ ! "$domain" =~ ^\.\.?$ ]]; then
            STATUS=$(docker exec nginx-proxy-acme test -f "/etc/nginx/certs/${domain}/fullchain.pem" 2>/dev/null && echo "✓" || echo "✗")
            printf "  %s  %-35s\n" "$STATUS" "$domain"
        fi
    done
else
    echo -e "${YELLOW}ℹ  nginx-proxy-acme non attivo${NC}"
fi

echo ""
echo -e "${BOLD}COMANDI UTILI:${NC}"
echo ""
echo "  # Monitoraggio tempo reale certificati"
echo "  docker logs -f nginx-proxy-acme"
echo ""
echo "  # Test HTTPS per un dominio"
echo "  curl -I https://ai.tuodominio.com"
echo ""
echo "  # Visualizza env di un container"
echo "  docker inspect <container> | grep -A 50 Env"
echo ""
echo "  # Reload nginx dopo cambio config"
echo "  docker exec nginx-proxy nginx -s reload"
echo ""
