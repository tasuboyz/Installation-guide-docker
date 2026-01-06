#!/bin/bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/docker_ops.sh"
source "${LIB_DIR}/vhost_manager.sh"

PROXY_ENV_PATTERNS="VIRTUAL_HOST VIRTUAL_PORT LETSENCRYPT_HOST LETSENCRYPT_EMAIL"

check_container_ssl_config() {
    local container_name="$1"
    local subdomain="$2"
    
    local current_vhost current_letsencrypt
    current_vhost=$(docker inspect "$container_name" --format='{{range .Config.Env}}{{if eq . (printf "VIRTUAL_HOST=%s" "'$subdomain'")}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")
    current_letsencrypt=$(docker inspect "$container_name" --format='{{range .Config.Env}}{{if eq . (printf "LETSENCRYPT_HOST=%s" "'$subdomain'")}}{{.}}{{end}}{{end}}' 2>/dev/null || echo "")
    
    [[ -n "$current_vhost" ]] && [[ -n "$current_letsencrypt" ]]
}

build_ssl_env_args() {
    local subdomain="$1"
    local port="$2"
    local email="$3"
    
    local env_args=""
    env_args+=" -e $(sh_quote "VIRTUAL_HOST=${subdomain}")"
    env_args+=" -e $(sh_quote "VIRTUAL_PORT=${port}")"
    env_args+=" -e $(sh_quote "LETSENCRYPT_HOST=${subdomain}")"
    env_args+=" -e $(sh_quote "LETSENCRYPT_EMAIL=${email}")"
    
    echo "$env_args"
}

build_container_run_cmd() {
    local container_name="$1"
    local network="$2"
    local mount_args="$3"
    local env_args="$4"
    local entrypoint="$5"
    local image="$6"
    local cmd="$7"
    
    local run_cmd="docker run -d --name ${container_name} --network ${network} --restart unless-stopped"
    run_cmd+=" ${mount_args} ${env_args}"
    
    if [[ -n "$entrypoint" ]]; then
        run_cmd+=" --entrypoint $(sh_quote "$entrypoint")"
    fi
    
    run_cmd+=" ${image}"
    
    if [[ -n "$cmd" ]]; then
        local cmd_escaped=""
        read -r -a cmd_array <<< "$cmd"
        for tok in "${cmd_array[@]}"; do
            cmd_escaped+=" $(sh_quote "${tok}")"
        done
        run_cmd+="${cmd_escaped}"
    fi
    
    echo "$run_cmd"
}

recreate_container_with_ssl() {
    local container_name="$1"
    local subdomain="$2"
    local port="$3"
    local email="$4"
    local network="$5"
    local auto_remove_backup="${6:-false}"
    
    if check_container_ssl_config "$container_name" "$subdomain"; then
        print_status "Container già configurato per SSL: $subdomain"
        return 0
    fi
    
    print_status "Backup configurazione container..."
    local current_image current_cmd current_entrypoint
    current_image=$(get_container_image "$container_name")
    current_cmd=$(get_container_cmd "$container_name")
    current_entrypoint=$(get_container_entrypoint "$container_name")
    
    local mount_args
    mount_args=$(get_container_mounts "$container_name")
    
    local env_args
    env_args=$(get_container_envs "$container_name" "$PROXY_ENV_PATTERNS")
    
    local ssl_env_args
    ssl_env_args=$(build_ssl_env_args "$subdomain" "$port" "$email")
    env_args+="$ssl_env_args"
    
    local original_networks additional_nets
    original_networks=$(get_container_networks "$container_name")
    additional_nets=""
    for net in $original_networks; do
        if [[ "$net" != "$network" ]]; then
            additional_nets+=" $net"
        fi
    done
    
    local tmp_name="${container_name}.__new__.${RANDOM}"
    local run_cmd
    run_cmd=$(build_container_run_cmd "$tmp_name" "$network" "$mount_args" "$env_args" "$current_entrypoint" "$current_image" "$current_cmd")
    
    print_status "Creazione container temporaneo..."
    set +e
    local new_id
    new_id=$(eval "$run_cmd" 2>&1)
    local rc=$?
    set -e
    
    if [[ $rc -ne 0 ]] || [[ -z "$new_id" ]]; then
        print_error "Errore creazione container temporaneo"
        remove_container "$tmp_name"
        return 1
    fi
    
    if ! wait_for_container "$tmp_name" 20; then
        print_error "Container temporaneo non avviato"
        get_container_logs "$tmp_name" 20
        remove_container "$tmp_name"
        return 1
    fi
    
    print_status "Container temporaneo in esecuzione"
    
    if [[ -n "$additional_nets" ]]; then
        for net in $additional_nets; do
            docker network connect "$net" "$tmp_name" 2>/dev/null || true
        done
        print_status "Reti aggiuntive connesse"
    fi
    
    local backup_name="${container_name}.__old__.$(date +%s)"
    
    stop_container "$container_name"
    rename_container "$container_name" "$backup_name"
    rename_container "$tmp_name" "$container_name"
    
    if is_container_running "$container_name"; then
        print_status "Swap completato: ${container_name}"
        
        if [[ "$auto_remove_backup" == "true" ]]; then
            remove_container "$backup_name"
            print_status "Backup rimosso"
        else
            print_warning "Backup mantenuto: ${backup_name}"
        fi
        return 0
    else
        print_error "Errore swap container - rollback"
        rename_container "$backup_name" "$container_name"
        remove_container "$tmp_name"
        return 1
    fi
}

configure_service_for_proxy() {
    local container_name="$1"
    local subdomain="$2"
    local port="$3"
    local email="$4"
    local network="$5"
    local auto_confirm="${6:-false}"
    
    connect_container_to_network "$container_name" "$network"
    
    local image
    image=$(get_container_image "$container_name")
    local service_type
    service_type=$(detect_special_service "$image" "$port")
    
    if [[ "$service_type" != "standard" ]]; then
        print_warning "Servizio speciale rilevato: $service_type"
        
        backup_vhost_config "$subdomain"
        
        local vhost_config
        vhost_config=$(create_vhost_config "$subdomain" "$container_name" "$port" "$image")
        save_vhost_config "$subdomain" "$vhost_config"
        
        if ! apply_vhost_config "$subdomain"; then
            return 1
        fi
    fi
    
    if ! recreate_container_with_ssl "$container_name" "$subdomain" "$port" "$email" "$network" "$auto_confirm"; then
        if [[ "$service_type" != "standard" ]]; then
            print_warning "Ricreazione fallita - configurazione vhost applicata"
            return 0
        fi
        return 1
    fi
    
    save_service_config "$container_name" "$subdomain" "$port" "$email" "$network"
    
    return 0
}

print_service_summary() {
    local container_name="$1"
    local subdomain="$2"
    local port="$3"
    local email="$4"
    local network="$5"
    local is_staging="${6:-false}"
    
    echo ""
    print_banner "CONFIGURAZIONE COMPLETATA"
    echo ""
    
    print_status "Il servizio ${container_name} è ora configurato per:"
    echo ""
    echo -e "  ${CYAN}https://${subdomain}${NC}"
    echo ""
    
    echo "Riepilogo:"
    echo "  Container:     ${container_name}"
    echo "  Sottodominio:  ${subdomain}"
    echo "  Porta:         ${port}"
    echo "  Email:         ${email}"
    echo "  Rete:          ${network}"
    echo ""
}
