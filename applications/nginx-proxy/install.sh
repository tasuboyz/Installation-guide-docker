#!/bin/bash

# =============================================================================
# NGINX REVERSE PROXY + SSL - SETUP COMPLETO AUTOMATIZZATO
# =============================================================================
# Questo script fa TUTTO:
# 1. Configura rete Docker
# 2. Configura email Let's Encrypt
# 3. Sceglie modalità SSL (staging/produzione)
# 4. Avvia nginx-proxy + acme-companion  
# 5. Seleziona container da esporre
# 6. Chiede sottodominio
# 7. Rileva porta
# 8. Crea configurazione vhost e la inietta nel proxy (persistente via volume)
# 9. Configura container con env per acme-companion
# 10. Servizio raggiungibile via HTTPS automaticamente
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_header() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Quote for safe shell usage: wrap in single quotes and escape internal single quotes
sh_quote() {
    local s
    s="$1"
    s="${s//'/"'"'}"
    printf "'%s'" "$s"
}

# =============================================================================
# PREREQUISITI
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    print_error "Esegui con: sudo ./install.sh"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker non installato"
    exit 1
fi

DCMD=""
# Rileva se è disponibile il plugin `docker compose` oppure il binario legacy `docker-compose`
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DCMD="docker compose"
elif command -v docker-compose &> /dev/null && docker-compose version &> /dev/null; then
    DCMD="docker-compose"
else
    print_error "Docker Compose non disponibile"
    exit 1
fi

clear
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║     NGINX REVERSE PROXY + SSL AUTOMATICO                      ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# STEP 1: RETE DOCKER
# =============================================================================

print_header "STEP 1/8 - Rete Docker"

DOCKER_NETWORK=""
LETSENCRYPT_EMAIL=""
ACME_CA_URI=""

if [[ -f .env ]]; then
    source .env 2>/dev/null || true
fi

echo "Reti Docker esistenti:"
docker network ls --format "  * {{.Name}}" | grep -v "bridge\|host\|none" || echo "  nessuna"
echo ""

if [[ -n "$DOCKER_NETWORK" ]]; then
    echo "Rete attuale da .env: ${DOCKER_NETWORK}"
    read -p "Usare questa rete? [Y/n]: " USE_NET
    USE_NET=${USE_NET:-y}
    USE_NET_LOWER=$(echo "$USE_NET" | tr '[:upper:]' '[:lower:]')
    [[ "$USE_NET_LOWER" != "y" ]] && DOCKER_NETWORK=""
fi

if [[ -z "$DOCKER_NETWORK" ]]; then
    read -p "Nome rete Docker [default: glpi-net]: " DOCKER_NETWORK
    DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}
fi

if ! docker network ls --format '{{.Name}}' | grep -q "^${DOCKER_NETWORK}$"; then
    print_warning "Rete '${DOCKER_NETWORK}' non esiste"
    read -p "Crearla? [Y/n]: " CREATE_NET
    CREATE_NET=${CREATE_NET:-y}
    if [[ "$(echo "$CREATE_NET" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
        docker network create "${DOCKER_NETWORK}"
        print_status "Rete creata"
    else
        print_error "Impossibile continuare"
        exit 1
    fi
else
    print_status "Rete '${DOCKER_NETWORK}' OK"
fi

# =============================================================================
# STEP 2: EMAIL
# =============================================================================

print_header "STEP 2/8 - Email Let's Encrypt"

if [[ -n "$LETSENCRYPT_EMAIL" ]]; then
    echo "Email attuale: ${LETSENCRYPT_EMAIL}"
    read -p "Usare questa email? [Y/n]: " USE_EMAIL
    USE_EMAIL=${USE_EMAIL:-y}
    [[ "$(echo "$USE_EMAIL" | tr '[:upper:]' '[:lower:]')" != "y" ]] && LETSENCRYPT_EMAIL=""
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    read -p "Email per Let's Encrypt: " LETSENCRYPT_EMAIL
fi

if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Email non valida"
    exit 1
fi

print_status "Email: ${LETSENCRYPT_EMAIL}"

# =============================================================================
# STEP 3: MODALITÀ SSL
# =============================================================================

print_header "STEP 3/8 - Modalità SSL"

echo "  1. PRODUZIONE - certificati validi limite: 5/settimana per dominio"
echo "  2. STAGING    - certificati test illimitati, per debug"
echo ""
read -p "Scegli [1/2, default: 1]: " SSL_CHOICE
SSL_CHOICE=${SSL_CHOICE:-1}

if [[ "$SSL_CHOICE" == "2" ]]; then
    ACME_CA_URI="https://acme-staging-v02.api.letsencrypt.org/directory"
    print_warning "STAGING attivo - certificati NON validi per browser"
else
    ACME_CA_URI=""
    print_status "PRODUZIONE - certificati validi"
fi

# =============================================================================
# STEP 4: AVVIO PROXY
# =============================================================================

print_header "STEP 4/8 - Avvio Nginx Proxy"

# Genera .env
cat > .env << EOF
# Auto-generated $(date)
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
DOCKER_NETWORK=${DOCKER_NETWORK}
EOF
[[ -n "$ACME_CA_URI" ]] && echo "ACME_CA_URI=${ACME_CA_URI}" >> .env

print_status ".env generato"

# Crea directory per vhost configs (persistente)
mkdir -p vhost-configs
chmod 755 vhost-configs

# Stop se running
if docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    echo "Riavvio proxy..."
    $DCMD down 2>/dev/null || true
    sleep 2
fi

echo "Avvio container..."
$DCMD up -d
sleep 5

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy"; then
    print_status "nginx-proxy attivo"
else
    print_error "Errore avvio nginx-proxy"
    exit 1
fi

if docker ps --format '{{.Names}}' | grep -q "nginx-proxy-acme"; then
    print_status "acme-companion attivo"
else
    print_error "Errore avvio acme-companion"
    exit 1
fi

# =============================================================================
# STEP 5: SELEZIONE CONTAINER
# =============================================================================

print_header "STEP 5/8 - Seleziona Container da Esporre"

CONTAINERS=$(docker ps --format '{{.Names}}' | grep -v "nginx-proxy" | sort)

if [[ -z "$CONTAINERS" ]]; then
    print_warning "Nessun container trovato oltre a nginx-proxy"
    echo ""
    echo "Avvia prima il servizio da esporre, poi riesegui:"
    echo "  sudo ./install.sh"
    exit 0
fi

echo "Container disponibili:"
echo ""
i=1
declare -A CMAP
while IFS= read -r c; do
    IMG=$(docker inspect "$c" --format='{{.Config.Image}}' 2>/dev/null | rev | cut -d/ -f1 | rev | cut -d: -f1)
    PTS=$(docker inspect "$c" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | tr -d '/tcpud' | xargs)
    printf "  %2d. %-25s [%s] ports: %s\n" "$i" "$c" "$IMG" "${PTS:-n/a}"
    CMAP[$i]="$c"
    ((i++))
done <<< "$CONTAINERS"

echo ""
read -p "Seleziona [1-$((i-1))]: " CCHOICE

if [[ -z "${CMAP[$CCHOICE]}" ]]; then
    print_error "Selezione non valida"
    exit 1
fi

CONTAINER_NAME="${CMAP[$CCHOICE]}"
print_status "Container: ${CONTAINER_NAME}"

# =============================================================================
# STEP 6: SOTTODOMINIO
# =============================================================================

print_header "STEP 6/8 - Sottodominio"

echo "Inserisci il sottodominio COMPLETO che vuoi usare per ${CONTAINER_NAME}"
echo ""
echo "Esempi:"
echo "  • n8n.tuodominio.com"
echo "  • chat.example.org"
echo "  • glpi.azienda.it"
echo ""
read -p "Sottodominio: " SUBDOMAIN

if [[ -z "$SUBDOMAIN" ]]; then
    print_error "Sottodominio obbligatorio"
    exit 1
fi

if [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*)?[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_error "Formato non valido: $SUBDOMAIN"
    exit 1
fi

print_status "Sottodominio: ${SUBDOMAIN}"

# Check DNS
if command -v dig &> /dev/null; then
    DNS=$(dig +short "$SUBDOMAIN" A 2>/dev/null | head -1 || echo "")
    if [[ -n "$DNS" ]]; then
        print_status "DNS: $DNS"
    else
        print_warning "DNS non configurato - configuralo prima di richiedere il certificato"
    fi
fi

# =============================================================================
# STEP 7: PORTA
# =============================================================================

print_header "STEP 7/8 - Porta Interna"

PORTS=$(docker inspect "$CONTAINER_NAME" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | tr ' ' '\n' | sed 's|/.*||' | sort -nu | grep -v '^$' || echo "")

if [[ -n "$PORTS" ]]; then
    PARR=($PORTS)
    PCOUNT=${#PARR[@]}
    
    if [[ $PCOUNT -eq 1 ]]; then
        INTERNAL_PORT="${PARR[0]}"
        echo "Porta rilevata: ${INTERNAL_PORT}"
        read -p "Usare questa porta? [Y/n]: " USE_PORT
        USE_PORT=${USE_PORT:-y}
        if [[ "$(echo "$USE_PORT" | tr '[:upper:]' '[:lower:]')" != "y" ]]; then
            read -p "Inserisci porta: " INTERNAL_PORT
        fi
    else
        echo "Porte rilevate:"
        j=1
        declare -A PMAP
        for p in "${PARR[@]}"; do
            echo "  $j. $p"
            PMAP[$j]="$p"
            ((j++))
        done
        echo ""
        read -p "Seleziona [1-$((j-1))]: " PCHOICE
        INTERNAL_PORT="${PMAP[$PCHOICE]:-}"
        if [[ -z "$INTERNAL_PORT" ]]; then
            read -p "Porta non valida. Inserisci manualmente: " INTERNAL_PORT
        fi
    fi
else
    read -p "Nessuna porta rilevata. Inserisci porta: " INTERNAL_PORT
fi

if [[ -z "$INTERNAL_PORT" ]]; then
    print_error "Porta obbligatoria"
    exit 1
fi

print_status "Porta: ${INTERNAL_PORT}"

# =============================================================================
# STEP 8: APPLICAZIONE AUTOMATICA
# =============================================================================

print_header "STEP 8/8 - Applicazione Automatica"

echo ""
echo "  Container:     ${CONTAINER_NAME}"
echo "  Sottodominio:  ${SUBDOMAIN}"
echo "  Porta:         ${INTERNAL_PORT}"
echo "  Email:         ${LETSENCRYPT_EMAIL}"
echo "  Rete:          ${DOCKER_NETWORK}"
echo "  Modalità:      $(if [[ -n "$ACME_CA_URI" ]]; then echo 'STAGING test'; else echo 'PRODUZIONE'; fi)"
echo ""
read -p "Procedo con la configurazione automatica? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [[ "$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')" != "y" ]]; then
    echo "Annullato"
    exit 0
fi

echo ""
echo "Configurazione in corso..."

# Connetti container alla rete se necessario
CNETS=$(docker inspect "$CONTAINER_NAME" --format='{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{end}}' 2>/dev/null)
if [[ ! "$CNETS" =~ $DOCKER_NETWORK ]]; then
    echo "  → Connessione a rete ${DOCKER_NETWORK}..."
    docker network connect "$DOCKER_NETWORK" "$CONTAINER_NAME" 2>/dev/null || true
    print_status "Container connesso alla rete"
fi

# Salva configurazione locale
CONFIG_FILE="configs/${CONTAINER_NAME}.conf"
mkdir -p configs
cat > "$CONFIG_FILE" << EOF
# Configurazione per ${CONTAINER_NAME}
# Generato: $(date)
CONTAINER=${CONTAINER_NAME}
SUBDOMAIN=${SUBDOMAIN}
PORT=${INTERNAL_PORT}
EMAIL=${LETSENCRYPT_EMAIL}
NETWORK=${DOCKER_NETWORK}
EOF

print_status "Config salvata: ${CONFIG_FILE}"

# Controlla se il container ha già le env proxy corrette
echo "  → Verifica configurazione attuale..."
CURRENT_VHOST=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{if eq . (printf "VIRTUAL_HOST=%s" "'$SUBDOMAIN'")}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")
CURRENT_LETSENCRYPT=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{if eq . (printf "LETSENCRYPT_HOST=%s" "'$SUBDOMAIN'")}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")

# Se già configurato correttamente, evita ricreazione
if [[ -n "$CURRENT_VHOST" ]] && [[ -n "$CURRENT_LETSENCRYPT" ]]; then
    print_status "Container già configurato per SSL: $SUBDOMAIN"
    echo "  → Configurazione esistente rilevata - saltando ricreazione"
    SKIP_RECREATION=true
else
    SKIP_RECREATION=false
    echo "  → Backup configurazione container..."
    CURRENT_IMAGE=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}')
    CURRENT_CMD=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Cmd}}{{.}} {{end}}')
    CURRENT_ENTRYPOINT=$(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Entrypoint}}{{.}} {{end}}')
fi

# Rilevamento servizi speciali che richiedono configurazione custom
IS_SPECIAL_SERVICE=false
SPECIAL_CONFIG=""

# Portainer (HTTPS backend interno)
if [[ "$CURRENT_IMAGE" =~ portainer ]] && [[ "$INTERNAL_PORT" == "9443" ]]; then
    IS_SPECIAL_SERVICE=true
    SPECIAL_CONFIG="portainer-https"
    print_warning "Rilevato Portainer con HTTPS interno - configurazione speciale necessaria"
fi

if [[ "$SKIP_RECREATION" == "false" ]]; then
    # Volumi (bind mounts e named volumes)
    MOUNT_ARGS=""
    while IFS= read -r mount; do
        TYPE=$(echo "$mount" | jq -r '.Type' 2>/dev/null || echo "unknown")
        SRC=$(echo "$mount" | jq -r '.Source' 2>/dev/null || echo "")
        DST=$(echo "$mount" | jq -r '.Destination' 2>/dev/null || echo "")
        if [[ "$TYPE" == "bind" ]] && [[ -n "$SRC" ]] && [[ -n "$DST" ]]; then
            MOUNT_ARGS="${MOUNT_ARGS} -v $(sh_quote "${SRC}:${DST}")"
        elif [[ "$TYPE" == "volume" ]] && [[ -n "$SRC" ]] && [[ -n "$DST" ]]; then
            MOUNT_ARGS="${MOUNT_ARGS} -v $(sh_quote "${SRC}:${DST}")"
        fi
    done < <(docker inspect "$CONTAINER_NAME" --format='{{json .Mounts}}' 2>/dev/null | jq -c '.[]' 2>/dev/null || echo '{}')

    # Environment variables (preserva esistenti + aggiungi proxy vars)
    ENV_ARGS=""
    while IFS= read -r env; do
        # Skip env già presenti che sovrascriveremo
        if [[ -n "$env" ]] && [[ ! "$env" =~ ^VIRTUAL_HOST= ]] && [[ ! "$env" =~ ^VIRTUAL_PORT= ]] && [[ ! "$env" =~ ^LETSENCRYPT_HOST= ]] && [[ ! "$env" =~ ^LETSENCRYPT_EMAIL= ]]; then
            ENV_ARGS="${ENV_ARGS} -e $(sh_quote "${env}")"
        fi
    done < <(docker inspect "$CONTAINER_NAME" --format='{{range .Config.Env}}{{println .}}{{end}}')

    # Aggiungi variabili per acme-companion
    ENV_ARGS="${ENV_ARGS} -e $(sh_quote "VIRTUAL_HOST=${SUBDOMAIN}")"
    ENV_ARGS="${ENV_ARGS} -e $(sh_quote "VIRTUAL_PORT=${INTERNAL_PORT}")"
    ENV_ARGS="${ENV_ARGS} -e $(sh_quote "LETSENCRYPT_HOST=${SUBDOMAIN}")"
    ENV_ARGS="${ENV_ARGS} -e $(sh_quote "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}")"
fi

if [[ "$SKIP_RECREATION" == "false" ]]; then
    # Ricreazione NON distruttiva: crea un nuovo container temporaneo, verifica, poi swap dei nomi
    echo "  - Creazione nuovo container temporaneo per applicare la configurazione SSL (swap non distruttivo)..."
    TMP_NAME="${CONTAINER_NAME}.__new__.$RANDOM"

    # Costruisci comando run per container temporaneo
    RUN_CMD="docker run -d --name ${TMP_NAME} --network ${DOCKER_NETWORK} --restart unless-stopped ${MOUNT_ARGS} ${ENV_ARGS}"
    # Escape entrypoint and cmd parts to avoid shell syntax errors when using eval
    if [[ -n "$CURRENT_ENTRYPOINT" ]]; then
        EP_ESCAPED=$(sh_quote "$CURRENT_ENTRYPOINT")
        RUN_CMD="${RUN_CMD} --entrypoint ${EP_ESCAPED}"
    fi

    RUN_CMD="${RUN_CMD} ${CURRENT_IMAGE}"
    if [[ -n "$CURRENT_CMD" ]]; then
        # Escape each word of CURRENT_CMD to preserve special chars
        CMD_ESCAPED=""
        # Use word-splitting to iterate tokens safely
        read -r -a _cmd_array <<< "$CURRENT_CMD"
        for _tok in "${_cmd_array[@]}"; do
            CMD_ESCAPED+=" $(sh_quote "${_tok}")"
        done
        RUN_CMD="${RUN_CMD}${CMD_ESCAPED}"
    fi

    # Esegui il container temporaneo
    # NOTE: debug: mostriamo il comando e non silenziamo gli errori per diagnosticare il problema
    echo "RUN_CMD: $RUN_CMD"
    set +e
    NEW_ID=$(eval "$RUN_CMD")
    RC=$?
    set -e
    if [[ $RC -ne 0 ]] || [[ -z "$NEW_ID" ]]; then
        print_error "Errore creazione del container temporaneo"
        print_warning "Potrebbe essere un servizio speciale che richiede configurazione manuale"
        # pulizia se necessario
        docker rm -f "$TMP_NAME" >/dev/null 2>&1 || true
        
        # Per servizi speciali, non fallire ma procedi con configurazione vhost
        if [[ "$IS_SPECIAL_SERVICE" == "true" ]]; then
            print_warning "Servizio speciale rilevato: applico solo configurazione nginx"
            SKIP_RECREATION=true
        else
            exit 1
        fi
    else
        print_status "Container temporaneo creato: ${TMP_NAME}"

        # Attendi che il nuovo container sia in stato 'running'
        echo "  → Attendo che il nuovo container sia in esecuzione..."
        for i in {1..20}; do
            if docker ps --format '{{.Names}}' | grep -q "^${TMP_NAME}$"; then
                break
            fi
            sleep 1
        done

        if ! docker ps --format '{{.Names}}' | grep -q "^${TMP_NAME}$"; then
            print_error "Il container temporaneo non è partito correttamente"
            docker logs "$TMP_NAME" || true
            docker rm -f "$TMP_NAME" >/dev/null 2>&1 || true
            
            if [[ "$IS_SPECIAL_SERVICE" == "true" ]]; then
                print_warning "Fallback per servizio speciale: applico solo configurazione nginx"
                SKIP_RECREATION=true
            else
                exit 1
            fi
        else
            print_status "Container temporaneo in esecuzione"

            # Ora esegui lo swap: ferma il container originale, rinominalo come backup, rinomina il nuovo col nome originale
            BACKUP_NAME="${CONTAINER_NAME}.__old__.$(date +%s)"
            echo "  → Arresto del container originale: ${CONTAINER_NAME}"
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true

            echo "  → Rinomina del container originale in backup: ${BACKUP_NAME}"
            docker rename "$CONTAINER_NAME" "$BACKUP_NAME" >/dev/null 2>&1 || true

            echo "  → Assegno il nome originale al nuovo container"
            docker rename "$TMP_NAME" "$CONTAINER_NAME"

            # Verifica che il nuovo container con il nome originale sia attivo
            if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                print_status "Swap completato: ${CONTAINER_NAME} ora punta al nuovo container"
            else
                print_error "Errore nello swap dei container. Ripristino il backup se possibile"
                # Tentativo di rollback
                docker rename "$BACKUP_NAME" "$CONTAINER_NAME" >/dev/null 2>&1 || true
                docker rm -f "$TMP_NAME" >/dev/null 2>&1 || true
                exit 1
            fi

            sleep 2

            # Offri la rimozione del backup (non rimuovere automaticamente)
            echo ""
            read -p "Vuoi rimuovere il container di backup ${BACKUP_NAME}? [y/N]: " REMOVE_BACKUP
            REMOVE_BACKUP=${REMOVE_BACKUP:-n}
            if [[ "$(echo "$REMOVE_BACKUP" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
                docker rm -f "$BACKUP_NAME" >/dev/null 2>&1 || true
                print_status "Backup rimosso: ${BACKUP_NAME}"
            else
                print_warning "Backup mantenuto: ${BACKUP_NAME} (puoi rimuoverlo manualmente quando sei sicuro)"
            fi
        fi
    fi
fi

# Crea configurazione vhost.d per servizi speciali o customizzazioni
if [[ "$IS_SPECIAL_SERVICE" == "true" ]] || [[ "$SKIP_RECREATION" == "true" ]]; then
    echo "  → Generazione configurazione nginx personalizzata..."
    
    # Backup configurazione esistente se presente
    if docker exec nginx-proxy test -f "/etc/nginx/vhost.d/${SUBDOMAIN}" 2>/dev/null; then
        docker exec nginx-proxy cp "/etc/nginx/vhost.d/${SUBDOMAIN}" "/tmp/${SUBDOMAIN}.backup.$(date +%s)" 2>/dev/null || true
        print_warning "Backup configurazione esistente creato"
    fi
    
    # Crea configurazione specifica
    VHOST_CONFIG=""
    if [[ "$SPECIAL_CONFIG" == "portainer-https" ]]; then
        VHOST_CONFIG="# Portainer HTTPS backend configuration\n"
        VHOST_CONFIG+="proxy_pass https://${CONTAINER_NAME}:${INTERNAL_PORT};\n"
        VHOST_CONFIG+="proxy_ssl_verify off;\n"
        VHOST_CONFIG+="proxy_ssl_session_reuse off;\n"
    else
        # Configurazione standard per altri servizi
        VHOST_CONFIG="# Custom configuration for ${SUBDOMAIN}\n"
        VHOST_CONFIG+="proxy_set_header Host \$host;\n"
        VHOST_CONFIG+="proxy_set_header X-Real-IP \$remote_addr;\n"
    fi
    
    # Scrivi configurazione
    echo -e "$VHOST_CONFIG" > "vhost-configs/${SUBDOMAIN}"
    docker cp "vhost-configs/${SUBDOMAIN}" nginx-proxy:"/etc/nginx/vhost.d/${SUBDOMAIN}"
    
    # Test e reload nginx
    if docker exec nginx-proxy nginx -t 2>&1 | grep -q "successful"; then
        docker exec nginx-proxy nginx -s reload
        print_status "Configurazione nginx personalizzata applicata"
    else
        print_error "Errore nella configurazione nginx - ripristino backup"
        docker exec nginx-proxy rm -f "/etc/nginx/vhost.d/${SUBDOMAIN}" 2>/dev/null || true
        exit 1
    fi
fi

# =============================================================================
# OUTPUT FINALE
# =============================================================================

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║               CONFIGURAZIONE COMPLETATA CON SUCCESSO          ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

print_status "Il servizio ${CONTAINER_NAME} è ora configurato per:"
echo ""
echo -e "  ${CYAN}https://${SUBDOMAIN}${NC}"
echo ""

if [[ -n "$ACME_CA_URI" ]]; then
    print_warning "ATTENZIONE: Modalità STAGING attiva"
    print_warning "Il certificato NON sarà valido per i browser"
    echo ""
fi

echo "Monitoraggio certificato SSL:"
echo "  docker logs -f nginx-proxy-acme"
echo ""
echo "Il certificato verrà emesso automaticamente in 1-2 minuti."
echo "Controlla i log per confermare:"
echo "  docker logs nginx-proxy-acme 2>&1 | grep '${SUBDOMAIN}'"
echo ""
echo "Test rapido dopo 1-2 min:"
echo "  curl -I https://${SUBDOMAIN}"
echo ""

# Chiedi se configurare altro
read -p "Configurare un altro servizio? [y/N]: " ANOTHER
ANOTHER=${ANOTHER:-n}
if [[ "$(echo "$ANOTHER" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
    exec "$0"
fi

print_status "Setup completato!"
