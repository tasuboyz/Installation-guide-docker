#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/docker_ops.sh"
source "${SCRIPT_DIR}/lib/ssl_config.sh"
source "${SCRIPT_DIR}/lib/prompts.sh"

DOCKER_NETWORK=""
LETSENCRYPT_EMAIL=""
ACME_CA_URI=""
AUTO_CONFIRM=false
SKIP_SERVICE_CONFIG=false

usage() {
    cat <<EOF
Usage: sudo ./install.sh [options]

Opzioni:
  --network, -n <name>    Nome rete Docker (default: auto-detect)
  --email, -e <email>     Email per Let's Encrypt
  --production            Certificati produzione (default)
  --staging               Certificati staging (test)
  --skip-services         Solo setup proxy, salta configurazione servizi
  --yes, -y               Modalità non-interattiva
  --help, -h              Mostra questo help

Esempi:
  sudo ./install.sh
  sudo ./install.sh --network mynet --email admin@example.com --yes
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --network|-n) DOCKER_NETWORK="$2"; shift 2;;
            --email|-e) LETSENCRYPT_EMAIL="$2"; shift 2;;
            --production) ACME_CA_URI=""; shift;;
            --staging) ACME_CA_URI=$(get_acme_uri "staging"); shift;;
            --skip-services) SKIP_SERVICE_CONFIG=true; shift;;
            --yes|-y) AUTO_CONFIRM=true; shift;;
            --help|-h) usage; exit 0;;
            *) print_error "Opzione sconosciuta: $1"; usage; exit 1;;
        esac
    done
}

setup_network() {
    print_header "RETE DOCKER"
    
    local auto_detected=""
    auto_detected=$(detect_network_from_containers 2>/dev/null || echo "")
    
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        DOCKER_NETWORK="${DOCKER_NETWORK:-${auto_detected:-glpi-net}}"
    else
        DOCKER_NETWORK=$(prompt_network_selection "$DOCKER_NETWORK" "$auto_detected" "glpi-net")
    fi
    
    if ! network_exists "$DOCKER_NETWORK"; then
        if [[ "$AUTO_CONFIRM" == "true" ]] || prompt_create_network "$DOCKER_NETWORK"; then
            docker network create "$DOCKER_NETWORK" >/dev/null
            print_status "Rete '${DOCKER_NETWORK}' creata"
        else
            print_error "Impossibile continuare senza rete"
            exit_user_error
        fi
    else
        print_status "Rete '${DOCKER_NETWORK}' OK"
    fi
}

setup_email() {
    print_header "EMAIL LET'S ENCRYPT"
    
    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
            print_error "--email richiesta in modalità non-interattiva"
            exit_user_error
        fi
    else
        LETSENCRYPT_EMAIL=$(prompt_email "$LETSENCRYPT_EMAIL")
    fi
    
    if ! validate_email "$LETSENCRYPT_EMAIL"; then
        print_error "Email non valida: $LETSENCRYPT_EMAIL"
        exit_user_error
    fi
    
    print_status "Email: ${LETSENCRYPT_EMAIL}"
}

setup_ssl_mode() {
    print_header "MODALITA SSL"
    
    if [[ "$AUTO_CONFIRM" == "false" ]] && [[ -z "$ACME_CA_URI" ]]; then
        local ssl_mode
        ssl_mode=$(prompt_ssl_mode)
        ACME_CA_URI=$(get_acme_uri "$ssl_mode")
    fi
    
    if is_staging_mode "$ACME_CA_URI"; then
        print_warning "STAGING attivo - certificati NON validi per browser"
    else
        print_status "PRODUZIONE - certificati validi"
    fi
}

start_proxy() {
    print_header "AVVIO NGINX PROXY"
    
    generate_env_file "$LETSENCRYPT_EMAIL" "$DOCKER_NETWORK" "$ACME_CA_URI" ".env"
    
    mkdir -p vhost-configs configs
    chmod 755 vhost-configs configs
    
    local dcmd
    dcmd=$(detect_docker_compose)
    
    if is_container_running "nginx-proxy"; then
        echo "Riavvio proxy..."
        $dcmd down 2>/dev/null || true
        sleep 2
    fi
    
    echo "Avvio container..."
    $dcmd up -d
    sleep 5
    
    if ! is_container_running "nginx-proxy"; then
        print_error "Errore avvio nginx-proxy"
        exit_system_error
    fi
    print_status "nginx-proxy attivo"
    
    if ! is_container_running "nginx-proxy-acme"; then
        print_error "Errore avvio acme-companion"
        exit_system_error
    fi
    print_status "acme-companion attivo"
}

offer_service_configuration() {
    if [[ "$SKIP_SERVICE_CONFIG" == "true" ]] || [[ "$AUTO_CONFIRM" == "true" ]]; then
        return
    fi
    
    local containers
    containers=$(list_containers_for_proxy 2>/dev/null || echo "")
    
    if [[ -z "$containers" ]]; then
        echo ""
        print_warning "Nessun container da configurare al momento."
        echo "Avvia i tuoi servizi, poi esegui: sudo ./add-service.sh"
        return
    fi
    
    echo ""
    read -p "Vuoi configurare subito dei servizi con SSL? [Y/n]: " configure_now
    configure_now=${configure_now:-y}
    
    if confirm_yes "$configure_now"; then
        exec "${SCRIPT_DIR}/add-service.sh"
    fi
}

print_completion() {
    echo ""
    print_banner "PROXY PRONTO"
    echo ""
    print_status "nginx-proxy e acme-companion sono attivi"
    echo ""
    echo "Per configurare servizi:"
    echo -e "  ${CYAN}sudo ./add-service.sh${NC}              # Wizard interattivo"
    echo -e "  ${CYAN}sudo ./add-service.sh --batch${NC}      # Configura più servizi"
    echo ""
}

main() {
    check_root
    check_docker
    
    load_env_file ".env"
    parse_args "$@"
    
    clear
    print_banner "NGINX REVERSE PROXY + SSL"
    
    setup_network
    setup_email
    setup_ssl_mode
    start_proxy
    print_completion
    offer_service_configuration
    
    print_status "Setup completato!"
}

main "$@"
