#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_ops.sh"
source "${SCRIPT_DIR}/lib/ssl_config.sh"
source "${SCRIPT_DIR}/lib/vhost_manager.sh"
source "${SCRIPT_DIR}/lib/container_setup.sh"
source "${SCRIPT_DIR}/lib/prompts.sh"

CONTAINER_NAME=""
SUBDOMAIN=""
INTERNAL_PORT=""
AUTO_CONFIRM=false
BATCH_MODE=false
BASE_DOMAIN=""

usage() {
    cat <<EOF
Usage: sudo ./add-service.sh [options]

Modalità Wizard (default):
  sudo ./add-service.sh              # Wizard interattivo singolo
  sudo ./add-service.sh --batch      # Wizard batch (più servizi)

Modalità CLI (automazione):
  sudo ./add-service.sh -c n8n -d n8n.example.com -p 5678 -y

Opzioni:
  --container, -c <name>  Nome container Docker
  --domain, -d <domain>   Sottodominio completo
  --port, -p <port>       Porta interna (auto-detect se omessa)
  --batch, -b             Modalità batch (configura più servizi)
  --base <domain>         Dominio base per batch (es: example.com)
  --yes, -y               Non-interattivo (richiede -c e -d)
  --list, -l              Lista servizi configurati
  --help, -h              Mostra questo help

Esempi:
  sudo ./add-service.sh
  sudo ./add-service.sh --batch --base example.com
  sudo ./add-service.sh -c n8n -d n8n.example.com -y
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --container|-c) CONTAINER_NAME="$2"; shift 2;;
            --domain|-d) SUBDOMAIN="$2"; shift 2;;
            --port|-p) INTERNAL_PORT="$2"; shift 2;;
            --batch|-b) BATCH_MODE=true; shift;;
            --base) BASE_DOMAIN="$2"; shift 2;;
            --yes|-y) AUTO_CONFIRM=true; shift;;
            --list|-l) list_configured_services; exit 0;;
            --help|-h) usage; exit 0;;
            *) print_error "Opzione sconosciuta: $1"; usage; exit 1;;
        esac
    done
}

check_proxy_running() {
    if ! is_container_running "nginx-proxy"; then
        print_error "nginx-proxy non in esecuzione. Esegui prima: sudo ./install.sh"
        exit_user_error
    fi
}

load_proxy_config() {
    load_env_file ".env"
    
    local env_network="${DOCKER_NETWORK:-}"
    local proxy_network=""
    if is_container_running "nginx-proxy"; then
        proxy_network=$(get_primary_user_network_of_container "nginx-proxy" 2>/dev/null || echo "")
    fi

    if [[ -n "$proxy_network" ]]; then
        if [[ -n "$env_network" ]] && [[ "$env_network" != "$proxy_network" ]]; then
            print_warning "Rete .env (${env_network}) diversa dalla rete reale di nginx-proxy (${proxy_network})"
        fi
        NETWORK="$proxy_network"
    else
        NETWORK="${env_network:-glpi-net}"
    fi

    if ! network_exists "$NETWORK"; then
        print_error "Rete Docker non trovata: ${NETWORK}"
        exit_user_error
    fi
    EMAIL="${LETSENCRYPT_EMAIL:-}"
    SSL_MODE="PRODUZIONE"
    IS_STAGING=false
    
    if [[ -n "${ACME_CA_URI:-}" ]]; then
        SSL_MODE="STAGING (test)"
        IS_STAGING=true
    fi
    
    if [[ -z "$EMAIL" ]]; then
        print_error "LETSENCRYPT_EMAIL non trovata. Esegui prima: sudo ./install.sh"
        exit_user_error
    fi
}

run_wizard_single() {
    while true; do
        echo ""
        print_header "SCANSIONE CONTAINER"
        
        if ! wizard_select_container_and_port; then
            exit_user_error
        fi
        
        CONTAINER_NAME="$SELECTED_CONTAINER"
        INTERNAL_PORT="$SELECTED_PORT"
        
        print_status "Selezionato: ${CONTAINER_NAME} (porta ${INTERNAL_PORT})"
        
        SUBDOMAIN=$(wizard_get_subdomain "$CONTAINER_NAME" "$BASE_DOMAIN")
        
        if [[ -z "$SUBDOMAIN" ]]; then
            print_error "Sottodominio obbligatorio"
            continue
        fi
        
        if ! validate_domain "$SUBDOMAIN"; then
            print_error "Formato dominio non valido: $SUBDOMAIN"
            continue
        fi
        
        check_dns_resolution "$SUBDOMAIN" || true
        
        if ! prompt_confirmation "$CONTAINER_NAME" "$SUBDOMAIN" "$INTERNAL_PORT" "$EMAIL" "$NETWORK" "$SSL_MODE"; then
            echo "Saltato."
            if ! prompt_another_service; then
                break
            fi
            continue
        fi
        
        apply_single_config
        
        if ! prompt_another_service; then
            break
        fi
    done
}

run_wizard_batch() {
    print_header "CONFIGURAZIONE BATCH"
    
    if ! wizard_batch_configure "$BASE_DOMAIN"; then
        echo "Annullato."
        exit_ok
    fi
    
    echo ""
    echo "Applicazione configurazioni..."
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for container in "${!BATCH_CONFIG[@]}"; do
        local config="${BATCH_CONFIG[$container]}"
        CONTAINER_NAME="$container"
        SUBDOMAIN="${config%|*}"
        INTERNAL_PORT="${config#*|}"
        
        echo -e "Configurazione ${BOLD}${CONTAINER_NAME}${NC} -> ${CYAN}${SUBDOMAIN}${NC}..."
        
        if apply_single_config_silent; then
            print_status "OK: https://${SUBDOMAIN}"
            ((success_count++))
        else
            print_error "FALLITO: ${CONTAINER_NAME}"
            ((fail_count++))
        fi
    done
    
    echo ""
    print_header "RIEPILOGO"
    echo -e "  Configurati: ${GREEN}${success_count}${NC}"
    [[ $fail_count -gt 0 ]] && echo -e "  Falliti:     ${RED}${fail_count}${NC}"
    echo ""
}

run_cli_mode() {
    if [[ -z "$CONTAINER_NAME" ]]; then
        print_error "--container richiesto in modalità CLI"
        exit_user_error
    fi
    
    if [[ -z "$SUBDOMAIN" ]]; then
        print_error "--domain richiesto in modalità CLI"
        exit_user_error
    fi
    
    if ! is_container_running "$CONTAINER_NAME"; then
        print_error "Container '${CONTAINER_NAME}' non in esecuzione"
        exit_user_error
    fi
    
    if [[ -z "$INTERNAL_PORT" ]]; then
        INTERNAL_PORT=$(get_container_ports "$CONTAINER_NAME" | head -1)
        if [[ -z "$INTERNAL_PORT" ]]; then
            print_error "--port richiesto (nessuna porta rilevata)"
            exit_user_error
        fi
        print_status "Porta auto-rilevata: ${INTERNAL_PORT}"
    fi
    
    if ! validate_domain "$SUBDOMAIN"; then
        print_error "Formato dominio non valido: $SUBDOMAIN"
        exit_user_error
    fi
    
    apply_single_config
}

apply_single_config() {
    echo ""
    echo "Configurazione in corso..."
    
    if ! configure_service_for_proxy "$CONTAINER_NAME" "$SUBDOMAIN" "$INTERNAL_PORT" "$EMAIL" "$NETWORK" "true"; then
        print_error "Configurazione fallita"
        return 1
    fi
    
    print_service_summary "$CONTAINER_NAME" "$SUBDOMAIN" "$INTERNAL_PORT" "$EMAIL" "$NETWORK" "$IS_STAGING"
    print_ssl_instructions "$SUBDOMAIN" "$IS_STAGING"
    return 0
}

apply_single_config_silent() {
    if ! configure_service_for_proxy "$CONTAINER_NAME" "$SUBDOMAIN" "$INTERNAL_PORT" "$EMAIL" "$NETWORK" "true" 2>/dev/null; then
        return 1
    fi
    return 0
}

main() {
    check_root
    check_docker
    
    parse_args "$@"
    check_proxy_running
    load_proxy_config
    
    clear
    print_banner "CONFIGURAZIONE SERVIZI SSL"
    
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        run_cli_mode
    elif [[ "$BATCH_MODE" == "true" ]]; then
        run_wizard_batch
    else
        run_wizard_single
    fi
    
    print_status "Completato!"
}

main "$@"
