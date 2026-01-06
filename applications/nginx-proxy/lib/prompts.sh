#!/bin/bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/docker_ops.sh"

prompt_network_selection() {
    local current_network="${1:-}"
    local auto_detected="${2:-}"
    local default_network="${3:-glpi-net}"
    
    echo "Reti Docker esistenti:"
    list_docker_networks
    echo ""
    
    if [[ -n "$auto_detected" ]]; then
        echo "Rete rilevata automaticamente: ${auto_detected}"
    fi
    
    if [[ -n "$current_network" ]]; then
        echo "Rete attuale da .env: ${current_network}"
        read -p "Usare questa rete? [Y/n]: " use_net
        use_net=${use_net:-y}
        if confirm_yes "$use_net"; then
            echo "$current_network"
            return 0
        fi
    fi
    
    local prompt_default="${auto_detected:-$default_network}"
    read -p "Nome rete Docker [default: ${prompt_default}]: " selected_network
    echo "${selected_network:-$prompt_default}"
}

prompt_create_network() {
    local network_name="$1"
    
    print_warning "Rete '${network_name}' non esiste"
    read -p "Crearla? [Y/n]: " create_net
    create_net=${create_net:-y}
    confirm_yes "$create_net"
}

prompt_email() {
    local current_email="${1:-}"
    
    if [[ -n "$current_email" ]]; then
        echo "Email attuale: ${current_email}"
        read -p "Usare questa email? [Y/n]: " use_email
        use_email=${use_email:-y}
        if confirm_yes "$use_email"; then
            echo "$current_email"
            return 0
        fi
    fi
    
    read -p "Email per Let's Encrypt: " email
    echo "$email"
}

prompt_ssl_mode() {
    echo "  1. PRODUZIONE - certificati validi (limite: 5/settimana per dominio)"
    echo "  2. STAGING    - certificati test illimitati, per debug"
    echo ""
    read -p "Scegli [1/2, default: 1]: " ssl_choice
    ssl_choice=${ssl_choice:-1}
    
    if [[ "$ssl_choice" == "2" ]]; then
        echo "staging"
    else
        echo "production"
    fi
}

scan_all_containers() {
    local containers
    containers=$(list_containers_for_proxy)
    
    if [[ -z "$containers" ]]; then
        return 1
    fi
    
    declare -gA CONTAINER_MAP
    declare -gA CONTAINER_PORTS
    declare -gA CONTAINER_IMAGES
    declare -ga CONTAINER_LIST
    
    local i=1
    while IFS= read -r c; do
        local info
        info=$(get_container_info "$c")
        local img="${info%|*}"
        local ports="${info#*|}"
        
        CONTAINER_MAP[$i]="$c"
        CONTAINER_PORTS[$c]="$ports"
        CONTAINER_IMAGES[$c]="$img"
        CONTAINER_LIST+=("$c")
        ((i++))
    done <<< "$containers"
    
    return 0
}

display_container_table() {
    echo ""
    echo -e "${BOLD}┌─────┬──────────────────────────────┬────────────────┬─────────────────┐${NC}"
    echo -e "${BOLD}│  #  │ Container                    │ Immagine       │ Porte           │${NC}"
    echo -e "${BOLD}├─────┼──────────────────────────────┼────────────────┼─────────────────┤${NC}"
    
    local i=1
    for c in "${CONTAINER_LIST[@]}"; do
        local img="${CONTAINER_IMAGES[$c]}"
        local ports="${CONTAINER_PORTS[$c]}"
        
        [[ ${#img} -gt 14 ]] && img="${img:0:12}.."
        [[ ${#ports} -gt 15 ]] && ports="${ports:0:13}.."
        [[ ${#c} -gt 28 ]] && c="${c:0:26}.."
        
        printf "│ %3d │ %-28s │ %-14s │ %-15s │\n" "$i" "$c" "$img" "$ports"
        ((i++))
    done
    
    echo -e "${BOLD}└─────┴──────────────────────────────┴────────────────┴─────────────────┘${NC}"
    echo ""
}

wizard_select_container_and_port() {
    if ! scan_all_containers; then
        print_warning "Nessun container trovato oltre a nginx-proxy"
        return 1
    fi
    
    display_container_table
    
    read -p "Seleziona container [1-${#CONTAINER_LIST[@]}]: " choice
    
    if [[ -z "${CONTAINER_MAP[$choice]:-}" ]]; then
        print_error "Selezione non valida"
        return 1
    fi
    
    SELECTED_CONTAINER="${CONTAINER_MAP[$choice]}"
    local ports="${CONTAINER_PORTS[$SELECTED_CONTAINER]}"
    
    if [[ "$ports" == "n/a" || -z "$ports" ]]; then
        read -p "Nessuna porta rilevata. Inserisci porta: " SELECTED_PORT
    else
        local port_array=($ports)
        if [[ ${#port_array[@]} -eq 1 ]]; then
            SELECTED_PORT="${port_array[0]}"
            echo -e "Porta auto-selezionata: ${GREEN}${SELECTED_PORT}${NC}"
        else
            echo "Porte disponibili: $ports"
            read -p "Quale porta usare? [default: ${port_array[0]}]: " port_choice
            SELECTED_PORT="${port_choice:-${port_array[0]}}"
        fi
    fi
    
    return 0
}

wizard_get_subdomain() {
    local container_name="$1"
    local base_domain="${2:-}"
    
    echo ""
    if [[ -n "$base_domain" ]]; then
        local suggested="${container_name%%_*}.${base_domain}"
        suggested="${suggested//_/-}"
        echo -e "Suggerimento: ${CYAN}${suggested}${NC}"
        read -p "Sottodominio [premi INVIO per usare suggerimento]: " subdomain
        subdomain="${subdomain:-$suggested}"
    else
        echo "Inserisci il sottodominio COMPLETO (es: app.tuodominio.com)"
        read -p "Sottodominio: " subdomain
    fi
    
    echo "$subdomain"
}

wizard_batch_configure() {
    local base_domain="${1:-}"
    
    if ! scan_all_containers; then
        print_warning "Nessun container trovato"
        return 1
    fi
    
    echo ""
    print_header "CONFIGURAZIONE BATCH"
    echo "Configura più servizi in una volta sola."
    echo ""
    
    if [[ -z "$base_domain" ]]; then
        read -p "Dominio base (es: example.com): " base_domain
    fi
    
    display_container_table
    
    echo "Inserisci i numeri dei container da configurare (separati da spazio)"
    echo "Esempio: 1 3 5"
    echo ""
    read -p "Container da configurare: " selections
    
    declare -gA BATCH_CONFIG
    
    for sel in $selections; do
        local container="${CONTAINER_MAP[$sel]:-}"
        [[ -z "$container" ]] && continue
        
        local ports="${CONTAINER_PORTS[$container]}"
        local port_array=($ports)
        local port="${port_array[0]:-80}"
        
        local suggested="${container%%_*}.${base_domain}"
        suggested="${suggested//_/-}"
        
        echo ""
        echo -e "Container: ${BOLD}${container}${NC} (porta: ${port})"
        read -p "Sottodominio [${suggested}]: " subdomain
        subdomain="${subdomain:-$suggested}"
        
        BATCH_CONFIG["${container}"]="${subdomain}|${port}"
    done
    
    echo ""
    print_header "RIEPILOGO CONFIGURAZIONE"
    echo ""
    echo -e "${BOLD}┌──────────────────────────────┬────────────────────────────────┬───────┐${NC}"
    echo -e "${BOLD}│ Container                    │ Sottodominio                   │ Porta │${NC}"
    echo -e "${BOLD}├──────────────────────────────┼────────────────────────────────┼───────┤${NC}"
    
    for container in "${!BATCH_CONFIG[@]}"; do
        local config="${BATCH_CONFIG[$container]}"
        local subdomain="${config%|*}"
        local port="${config#*|}"
        printf "│ %-28s │ %-30s │ %5s │\n" "$container" "$subdomain" "$port"
    done
    
    echo -e "${BOLD}└──────────────────────────────┴────────────────────────────────┴───────┘${NC}"
    echo ""
    
    read -p "Procedere con la configurazione? [Y/n]: " confirm
    confirm=${confirm:-y}
    confirm_yes "$confirm"
}

prompt_confirmation() {
    local container_name="$1"
    local subdomain="$2"
    local port="$3"
    local email="$4"
    local network="$5"
    local ssl_mode="$6"
    
    echo ""
    echo -e "  Container:     ${BOLD}${container_name}${NC}"
    echo -e "  Sottodominio:  ${CYAN}${subdomain}${NC}"
    echo -e "  Porta:         ${port}"
    echo -e "  Email:         ${email}"
    echo -e "  Rete:          ${network}"
    echo -e "  Modalità:      ${ssl_mode}"
    echo ""
    read -p "Procedo con la configurazione? [Y/n]: " confirm
    confirm=${confirm:-y}
    
    confirm_yes "$confirm"
}

prompt_another_service() {
    echo ""
    read -p "Configurare un altro servizio? [Y/n]: " another
    another=${another:-y}
    confirm_yes "$another"
}

prompt_remove_backup() {
    local backup_name="$1"
    
    read -p "Rimuovere il container di backup ${backup_name}? [y/N]: " remove
    remove=${remove:-n}
    confirm_yes "$remove"
}
