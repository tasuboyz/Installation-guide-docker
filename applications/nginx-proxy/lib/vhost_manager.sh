#!/bin/bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/docker_ops.sh"

VHOST_CONFIGS_DIR="vhost-configs"

ensure_vhost_dir() {
    mkdir -p "$VHOST_CONFIGS_DIR"
    chmod 755 "$VHOST_CONFIGS_DIR"
}

create_standard_vhost_config() {
    local subdomain="$1"
    local config=""
    
    config+="proxy_set_header Host \$host;\n"
    config+="proxy_set_header X-Real-IP \$remote_addr;\n"
    config+="proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
    config+="proxy_set_header X-Forwarded-Proto \$scheme;\n"
    
    echo -e "$config"
}

create_portainer_https_config() {
    local container_name="$1"
    local port="$2"
    local config=""
    
    config+="proxy_pass https://${container_name}:${port};\n"
    config+="proxy_ssl_verify off;\n"
    config+="proxy_ssl_session_reuse off;\n"
    
    echo -e "$config"
}

create_websocket_config() {
    local config=""
    
    config+="proxy_http_version 1.1;\n"
    config+="proxy_set_header Upgrade \$http_upgrade;\n"
    config+="proxy_set_header Connection \"upgrade\";\n"
    config+="proxy_read_timeout 86400;\n"
    
    echo -e "$config"
}

create_api_config() {
    local config=""
    
    config+="proxy_set_header Authorization \$http_authorization;\n"
    config+="proxy_set_header api_access_token \$http_api_access_token;\n"
    config+="proxy_pass_header Authorization;\n"
    
    echo -e "$config"
}

detect_special_service() {
    local image="$1"
    local port="$2"
    
    if [[ "$image" =~ portainer ]] && [[ "$port" == "9443" ]]; then
        echo "portainer-https"
        return 0
    fi
    
    if [[ "$image" =~ n8n|websocket|socket\.io ]]; then
        echo "websocket"
        return 0
    fi
    
    if [[ "$image" =~ chatwoot ]]; then
        echo "api"
        return 0
    fi
    
    echo "standard"
}

create_vhost_config() {
    local subdomain="$1"
    local container_name="$2"
    local port="$3"
    local image="${4:-}"
    
    local service_type
    service_type=$(detect_special_service "$image" "$port")
    
    local config=""
    case "$service_type" in
        portainer-https)
            config=$(create_portainer_https_config "$container_name" "$port")
            ;;
        websocket)
            config=$(create_standard_vhost_config "$subdomain")
            config+=$(create_websocket_config)
            ;;
        api)
            config=$(create_standard_vhost_config "$subdomain")
            config+=$(create_api_config)
            ;;
        *)
            config=$(create_standard_vhost_config "$subdomain")
            ;;
    esac
    
    echo -e "$config"
}

save_vhost_config() {
    local subdomain="$1"
    local config="$2"
    
    ensure_vhost_dir
    echo -e "$config" > "${VHOST_CONFIGS_DIR}/${subdomain}"
}

backup_vhost_config() {
    local subdomain="$1"
    local timestamp
    timestamp=$(date +%s)
    
    if docker exec nginx-proxy test -f "/etc/nginx/vhost.d/${subdomain}" 2>/dev/null; then
        docker exec nginx-proxy cp "/etc/nginx/vhost.d/${subdomain}" "/tmp/${subdomain}.backup.${timestamp}" 2>/dev/null || true
        print_warning "Backup configurazione esistente creato"
        return 0
    fi
    return 1
}

apply_vhost_config() {
    local subdomain="$1"
    
    if [[ ! -f "${VHOST_CONFIGS_DIR}/${subdomain}" ]]; then
        print_error "File config non trovato: ${VHOST_CONFIGS_DIR}/${subdomain}"
        return 1
    fi
    
    docker cp "${VHOST_CONFIGS_DIR}/${subdomain}" nginx-proxy:"/etc/nginx/vhost.d/${subdomain}"
    
    if docker exec nginx-proxy nginx -t 2>&1 | grep -q "successful"; then
        docker exec nginx-proxy nginx -s reload
        print_status "Configurazione nginx applicata"
        return 0
    else
        print_error "Errore nella configurazione nginx"
        docker exec nginx-proxy rm -f "/etc/nginx/vhost.d/${subdomain}" 2>/dev/null || true
        return 1
    fi
}

remove_vhost_config() {
    local subdomain="$1"
    
    docker exec nginx-proxy rm -f "/etc/nginx/vhost.d/${subdomain}" 2>/dev/null || true
    rm -f "${VHOST_CONFIGS_DIR}/${subdomain}" 2>/dev/null || true
    
    if docker exec nginx-proxy nginx -t 2>&1 | grep -q "successful"; then
        docker exec nginx-proxy nginx -s reload
    fi
}

save_service_config() {
    local container_name="$1"
    local subdomain="$2"
    local port="$3"
    local email="$4"
    local network="$5"
    
    local config_dir="configs"
    mkdir -p "$config_dir"
    
    cat > "${config_dir}/${container_name}.conf" << EOF
CONTAINER=${container_name}
SUBDOMAIN=${subdomain}
PORT=${port}
EMAIL=${email}
NETWORK=${network}
EOF
    
    print_status "Config salvata: ${config_dir}/${container_name}.conf"
}

list_configured_services() {
    local config_dir="configs"
    
    if [[ ! -d "$config_dir" ]]; then
        echo "Nessun servizio configurato"
        return 1
    fi
    
    echo "Servizi configurati:"
    echo ""
    
    for conf_file in "${config_dir}"/*.conf; do
        [[ -f "$conf_file" ]] || continue
        
        local container subdomain port
        container=$(grep "^CONTAINER=" "$conf_file" | cut -d= -f2)
        subdomain=$(grep "^SUBDOMAIN=" "$conf_file" | cut -d= -f2)
        port=$(grep "^PORT=" "$conf_file" | cut -d= -f2)
        
        printf "  %-20s → https://%s (:%s)\n" "$container" "$subdomain" "$port"
    done
}
