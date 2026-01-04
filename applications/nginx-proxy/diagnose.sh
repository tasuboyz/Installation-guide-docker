#!/bin/bash
# =============================================================================
# SCRIPT: Diagnostica Completa - Stato Servizi + Certificati
# Uso: ./diagnose.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_section() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_status() {
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# =============================================================================

print_section "1. STATO DOCKER"

echo ""
echo "Docker daemon:"
docker ps > /dev/null 2>&1
check_status "Docker in esecuzione"

echo ""
echo "Docker Compose:"
docker compose version | head -1 || echo -e "${RED}✗${NC} Docker Compose non disponibile"

echo ""
echo "Versioni:"
docker --version
docker compose version --short 2>/dev/null || echo "N/A"

# =============================================================================

print_section "2. RETI DOCKER"

echo ""
docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -E "glpi-net|proxy-network|app-network" || echo "Nessuna rete proxy trovata"

# =============================================================================

print_section "3. CONTAINER NGINX-PROXY"

echo ""
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy$"; then
    echo -e "${GREEN}✓${NC} nginx-proxy attivo"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep nginx-proxy
else
    echo -e "${RED}✗${NC} nginx-proxy NON ATTIVO"
fi

echo ""
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    echo -e "${GREEN}✓${NC} nginx-proxy-acme attivo"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep nginx-proxy-acme
else
    echo -e "${RED}✗${NC} nginx-proxy-acme NON ATTIVO"
fi

# =============================================================================

print_section "4. CONTAINER CON SSL CONFIGURATO"

echo ""
FOUND_ANY=false
docker ps --format '{{.Names}}' | while read container; do
    VHOST=$(docker inspect "$container" --format='{{range .Config.Env}}{{if contains . "VIRTUAL_HOST="}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")
    
    if [[ -n "$VHOST" ]]; then
        FOUND_ANY=true
        VPORT=$(docker inspect "$container" --format='{{range .Config.Env}}{{if contains . "VIRTUAL_PORT="}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "default")
        STATUS=$(docker ps --format '{{.Status}}' --filter "name=$container" 2>/dev/null | head -1)
        
        printf "  %-25s ${GREEN}%s${NC}\n" "$container" "${VHOST#VIRTUAL_HOST=}"
        printf "    └─ Port: ${VPORT#VIRTUAL_PORT=} | Status: $STATUS\n"
    fi
done

if ! $FOUND_ANY; then
    echo "Nessun container con VIRTUAL_HOST trovato"
fi

# =============================================================================

print_section "5. CERTIFICATI SSL EMESSI"

echo ""
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    CERTS_COUNT=$(docker exec nginx-proxy-acme ls -1 /etc/acme.sh/ 2>/dev/null | grep -v "^\." | wc -l || echo "0")
    echo "Certificati Let's Encrypt emessi: $CERTS_COUNT"
    echo ""
    
    docker exec nginx-proxy-acme ls -1 /etc/acme.sh/ 2>/dev/null | grep -v "^\." | while read domain; do
        if [[ ! "$domain" =~ ^\.\.?$ ]]; then
            # Controlla data di scadenza
            CERT_FILE="/etc/acme.sh/${domain}/fullchain.pem"
            if docker exec nginx-proxy-acme test -f "$CERT_FILE" 2>/dev/null; then
                EXPIRY=$(docker exec nginx-proxy-acme openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2 || echo "N/A")
                printf "  %-40s ${GREEN}✓${NC} Scade: %s\n" "$domain" "$EXPIRY"
            else
                printf "  %-40s ${YELLOW}⏳${NC} In elaborazione...\n" "$domain"
            fi
        fi
    done
else
    echo -e "${RED}✗${NC} nginx-proxy-acme non attivo - impossibile verificare certificati"
fi

# =============================================================================

print_section "6. CONFIGURAZIONE DOMINI (.env.domains)"

echo ""
if [[ -f ".env.domains" ]]; then
    echo "Configurazione trovata:"
    echo ""
    grep -v "^#" .env.domains | grep -v "^$" | while read line; do
        KEY=$(echo "$line" | cut -d= -f1)
        VALUE=$(echo "$line" | cut -d= -f2-)
        printf "  %-30s %s\n" "$KEY" "$VALUE"
    done
else
    echo -e "${YELLOW}ℹ${NC}  .env.domains non trovato"
    echo "   Esegui: sudo ./setup-domains.sh"
fi

# =============================================================================

print_section "7. CONFIGURAZIONE FILE (configs/ + vhost-configs/)"

echo ""
if [[ -d "configs" ]] && [[ -n "$(ls -1 configs/ 2>/dev/null)" ]]; then
    echo "Configurazioni salvate (configs/):"
    ls -1 configs/ | while read file; do
        printf "  • %s\n" "$file"
    done
else
    echo -e "${YELLOW}ℹ${NC}  Nessuna configurazione salvata in configs/"
fi

echo ""
if [[ -d "vhost-configs" ]] && [[ -n "$(ls -1 vhost-configs/ 2>/dev/null)" ]]; then
    echo "Configurazioni nginx (vhost-configs/):"
    ls -1 vhost-configs/ | while read file; do
        printf "  • %s\n" "$file"
    done
else
    echo -e "${YELLOW}ℹ${NC}  Nessuna configurazione nginx in vhost-configs/"
fi

# =============================================================================

print_section "8. TEST CONNETTIVITÀ TRA CONTAINER"

echo ""
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy$"; then
    echo "Test ping da nginx-proxy a container:"
    docker ps --format '{{.Names}}' | grep -v "nginx-proxy" | head -3 | while read container; do
        RESULT=$(docker exec nginx-proxy ping -c 1 "$container" 2>&1 | grep -q "1 packets received" && echo "OK" || echo "FAIL")
        printf "  → nginx-proxy → %-25s [%s]\n" "$container" "$RESULT"
    done
else
    echo -e "${RED}✗${NC} nginx-proxy non attivo"
fi

# =============================================================================

print_section "9. LOG RECENTI nginx-proxy-acme"

echo ""
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    docker logs --tail 20 nginx-proxy-acme 2>&1 | tail -10 || echo "Nessun log disponibile"
else
    echo -e "${RED}✗${NC} nginx-proxy-acme non attivo"
fi

# =============================================================================

print_section "10. COMANDI UTILI SUCCESSIVI"

echo ""
echo "Monitoraggio tempo reale:"
echo "  docker logs -f nginx-proxy-acme"
echo ""
echo "Test HTTPS (sostituisci ai.tuodominio.com):"
echo "  curl -I https://ai.tuodominio.com"
echo ""
echo "Verifica configurazione nginx:"
echo "  docker exec nginx-proxy nginx -t"
echo ""
echo "Reload nginx dopo cambio config:"
echo "  docker exec nginx-proxy nginx -s reload"
echo ""

# =============================================================================

echo -e "${GREEN}✓${NC} Diagnostica completata"
