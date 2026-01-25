#!/bin/bash

# Script diagnostico Chatwoot
# Uso: bash diagnose-chatwoot.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== DIAGNOSTICA CHATWOOT ===${NC}"
echo ""

cd "$(dirname "$0")"

echo -e "${YELLOW}1. Stato container:${NC}"
docker compose ps
echo ""

echo -e "${YELLOW}2. Log Rails (ultimi 50 righe):${NC}"
docker compose logs --tail 50 rails
echo ""

echo -e "${YELLOW}3. Log Sidekiq (ultimi 30 righe):${NC}"
docker compose logs --tail 30 sidekiq
echo ""

echo -e "${YELLOW}4. Verifica database:${NC}"
docker compose exec postgres psql -U postgres -c "\l" 2>/dev/null || echo "PostgreSQL non accessibile"
echo ""

echo -e "${YELLOW}5. Verifica tabelle database:${NC}"
docker compose exec postgres psql -U postgres -d chatwoot -c "\dt" 2>/dev/null | head -20 || echo "Database chatwoot non accessibile"
echo ""

echo -e "${YELLOW}6. Verifica connessione Rails -> DB:${NC}"
docker compose exec rails bundle exec rails runner "puts 'DB OK: ' + Account.count.to_s + ' accounts'" 2>&1 || echo "Errore connessione DB"
echo ""

echo -e "${YELLOW}7. Verifica Redis:${NC}"
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping 2>/dev/null || echo "Redis non accessibile"
echo ""

echo -e "${YELLOW}8. Variabili ambiente Rails (filtrate):${NC}"
docker compose exec rails env | grep -E "(POSTGRES|REDIS|FRONTEND|VIRTUAL|RAILS_ENV)" | sort
echo ""

echo -e "${YELLOW}9. Spazio disco:${NC}"
df -h | grep -E "(Filesystem|/$|/var)"
echo ""

echo -e "${YELLOW}10. Ultime righe log production (se accessibile):${NC}"
docker compose exec rails tail -30 /app/log/production.log 2>/dev/null || echo "Log non accessibile"
echo ""

echo -e "${GREEN}=== DIAGNOSTICA COMPLETATA ===${NC}"
echo ""
echo "Per log dettagliati:"
echo "  docker compose logs -f rails"
echo "  docker compose logs -f sidekiq"
