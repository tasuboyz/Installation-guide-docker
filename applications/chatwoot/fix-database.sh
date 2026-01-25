#!/bin/bash

# Script per risolvere il problema del database Chatwoot
# Uso: bash fix-database.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== FIX DATABASE CHATWOOT ===${NC}"
echo ""

cd "$(dirname "$0")"

# 1. Ferma i container rails e sidekiq (lascia postgres e redis attivi)
echo -e "${YELLOW}1. Fermando containers rails e sidekiq...${NC}"
docker compose stop rails sidekiq 2>/dev/null || true
sleep 2

# 2. Verifica che postgres sia in esecuzione
echo -e "${YELLOW}2. Verificando PostgreSQL...${NC}"
if ! docker compose ps postgres | grep -q "Up"; then
    echo -e "${RED}PostgreSQL non è in esecuzione. Avvio...${NC}"
    docker compose up -d postgres
    sleep 5
fi
echo -e "${GREEN}✓ PostgreSQL è attivo${NC}"

# 3. Crea il database
echo -e "${YELLOW}3. Creando database chatwoot...${NC}"
docker compose run --rm rails bundle exec rails db:create
echo -e "${GREEN}✓ Database creato${NC}"

# 4. Esegui le migrazioni
echo -e "${YELLOW}4. Eseguendo migrazioni...${NC}"
docker compose run --rm rails bundle exec rails db:migrate
echo -e "${GREEN}✓ Migrazioni completate${NC}"

# 5. (Opzionale) Seed del database per dati iniziali
echo -e "${YELLOW}5. Vuoi caricare i dati iniziali (seed)? [s/N]${NC}"
read -r -p "> " risposta
if [[ "$risposta" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Caricamento seed...${NC}"
    docker compose run --rm rails bundle exec rails db:seed
    echo -e "${GREEN}✓ Seed completato${NC}"
else
    echo -e "${YELLOW}Seed saltato${NC}"
fi

# 6. Riavvia tutti i servizi
echo -e "${YELLOW}6. Riavviando tutti i servizi...${NC}"
docker compose up -d
sleep 5

# 7. Verifica lo stato
echo -e "${YELLOW}7. Verifica stato servizi:${NC}"
docker compose ps

echo ""
echo -e "${GREEN}=== COMPLETATO ===${NC}"
echo ""
echo "Controlla i log con:"
echo "  docker compose logs -f rails"
echo ""
echo "Accedi a Chatwoot su:"
echo "  https://chatwoot.tasuthor.com"
echo ""
