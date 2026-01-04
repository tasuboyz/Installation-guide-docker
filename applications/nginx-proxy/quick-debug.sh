#!/bin/bash
# =============================================================================
# QUICK DEBUG - Recupera informazioni veloci
# Uso: ./quick-debug.sh
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  QUICK DEBUG - Informazioni Sistema${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# 1. Docker Status
echo -e "${BOLD}1. Docker Status${NC}"
if docker ps > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker in esecuzione"
else
    echo -e "${RED}✗${NC} Docker NON in esecuzione"
fi
echo ""

# 2. nginx-proxy Status
echo -e "${BOLD}2. Nginx-Proxy Status${NC}"
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy$"; then
    echo -e "${GREEN}✓${NC} nginx-proxy attivo"
else
    echo -e "${RED}✗${NC} nginx-proxy NON ATTIVO"
fi

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    echo -e "${GREEN}✓${NC} nginx-proxy-acme attivo"
else
    echo -e "${RED}✗${NC} nginx-proxy-acme NON ATTIVO"
fi
echo ""

# 3. Configured Domains
echo -e "${BOLD}3. Domini Configurati${NC}"
if [[ -f ".env.domains" ]]; then
    echo -e "${GREEN}✓${NC} File .env.domains trovato"
    grep "SUBDOMAIN" .env.domains | cut -d= -f2 | sort -u | while read domain; do
        echo "  → $domain"
    done
else
    echo -e "${RED}✗${NC} File .env.domains NON trovato"
fi
echo ""

# 4. Container con VIRTUAL_HOST
echo -e "${BOLD}4. Container Esposti${NC}"
FOUND=false
docker ps --format '{{.Names}}' | while read container; do
    VHOST=$(docker inspect "$container" --format='{{range .Config.Env}}{{if contains . "VIRTUAL_HOST="}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")
    if [[ -n "$VHOST" ]]; then
        FOUND=true
        echo "  → ${VHOST#VIRTUAL_HOST=}"
    fi
done
if ! $FOUND; then
    echo "  (nessun container configurato)"
fi
echo ""

# 5. SSL Certificates
echo -e "${BOLD}5. Certificati SSL${NC}"
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    CERT_COUNT=$(docker exec nginx-proxy-acme ls -1 /etc/acme.sh/ 2>/dev/null | grep -v "^\." | wc -l || echo "0")
    echo -e "${GREEN}✓${NC} Certificati: $CERT_COUNT"
    docker exec nginx-proxy-acme ls -1 /etc/acme.sh/ 2>/dev/null | grep -v "^\." | while read domain; do
        echo "  → $domain"
    done
else
    echo -e "${RED}✗${NC} nginx-proxy-acme non disponibile"
fi
echo ""

# 6. Ultimo errore log
echo -e "${BOLD}6. Log Ultimi Errori (ultimi 5)${NC}"
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    ERRORS=$(docker logs nginx-proxy-acme 2>&1 | grep -i "error\|failed" | tail -5 || echo "Nessun errore")
    if [[ "$ERRORS" != "Nessun errore" ]]; then
        echo "$ERRORS"
    else
        echo -e "${GREEN}✓${NC} Nessun errore rilevato"
    fi
else
    echo "nginx-proxy-acme non attivo"
fi
echo ""

# 7. Test URL
echo -e "${BOLD}7. Test Veloce DNS${NC}"
if [[ -f ".env.domains" ]]; then
    FIRST_DOMAIN=$(grep "SUBDOMAIN" .env.domains | head -1 | cut -d= -f2 | grep -v "^$" || echo "")
    if [[ -n "$FIRST_DOMAIN" ]]; then
        if command -v dig &> /dev/null; then
            RESULT=$(dig +short "$FIRST_DOMAIN" 2>/dev/null | head -1 || echo "")
            if [[ -n "$RESULT" ]]; then
                echo -e "${GREEN}✓${NC} DNS OK: $FIRST_DOMAIN → $RESULT"
            else
                echo -e "${RED}✗${NC} DNS non risolto: $FIRST_DOMAIN"
            fi
        else
            echo -e "${BOLD}ℹ${NC}  dig non disponibile"
        fi
    fi
fi
echo ""

# 8. Connessione Container
echo -e "${BOLD}8. Test Connettività${NC}"
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy$"; then
    TEST_CONTAINER=$(docker ps --format '{{.Names}}' | grep -v "nginx-proxy" | head -1)
    if [[ -n "$TEST_CONTAINER" ]]; then
        if docker exec nginx-proxy ping -c 1 "$TEST_CONTAINER" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} nginx-proxy ↔ $TEST_CONTAINER: OK"
        else
            echo -e "${RED}✗${NC} nginx-proxy ↔ $TEST_CONTAINER: FAILED"
        fi
    fi
fi
echo ""

echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Fine DEBUG${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
