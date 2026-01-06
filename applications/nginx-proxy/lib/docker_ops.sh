#!/bin/bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/common.sh"

is_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

container_exists() {
    local container_name="$1"
    docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

network_exists() {
    local network_name="$1"
    docker network ls --format '{{.Name}}' | grep -q "^${network_name}$"
}

ensure_network() {
    local network_name="$1"
    if ! network_exists "$network_name"; then
        docker network create "$network_name" >/dev/null
        print_status "Rete '${network_name}' creata"
    else
        print_status "Rete '${network_name}' OK"
    fi
}

detect_network_from_containers() {
    local exclude_pattern="${1:-nginx-proxy}"
    local containers
    containers=$(docker ps --format '{{.Names}}' | grep -v "$exclude_pattern" | head -5)
    
    [[ -z "$containers" ]] && return 1
    
    declare -A net_count
    local container cnets net max_count=0 detected_net=""
    
    for container in $containers; do
        cnets=$(docker inspect "$container" --format='{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{end}}' 2>/dev/null)
        for net in $cnets; do
            [[ "$net" =~ ^(bridge|host|none)$ ]] && continue
            net_count[$net]=$((${net_count[$net]:-0} + 1))
        done
    done
    
    for net in "${!net_count[@]}"; do
        if [[ ${net_count[$net]} -gt $max_count ]]; then
            max_count=${net_count[$net]}
            detected_net="$net"
        fi
    done
    
    [[ -n "$detected_net" ]] && echo "$detected_net"
}

list_docker_networks() {
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | grep -v "^bridge\|^host\|^none\|^NETWORK" || echo "  nessuna"
}

get_container_image() {
    local container_name="$1"
    docker inspect "$container_name" --format='{{.Config.Image}}' 2>/dev/null
}

get_container_ports() {
    local container_name="$1"
    docker inspect "$container_name" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | \
        tr ' ' '\n' | sed 's|/.*||' | sort -nu | grep -v '^$'
}

get_container_networks() {
    local container_name="$1"
    docker inspect "$container_name" --format='{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{end}}' 2>/dev/null | xargs
}

get_container_cmd() {
    local container_name="$1"
    docker inspect "$container_name" --format='{{range .Config.Cmd}}{{.}} {{end}}' 2>/dev/null | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

get_container_entrypoint() {
    local container_name="$1"
    docker inspect "$container_name" --format='{{range .Config.Entrypoint}}{{.}} {{end}}' 2>/dev/null | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

get_container_mounts() {
    local container_name="$1"
    local tmp_file
    tmp_file=$(mktemp)
    
    docker inspect "$container_name" --format='{{json .Mounts}}' 2>/dev/null | jq -c '.[]' 2>/dev/null > "$tmp_file" || echo '{}' > "$tmp_file"
    
    local mount_args=""
    while IFS= read -r mount; do
        local mount_type src dst
        mount_type=$(echo "$mount" | jq -r '.Type' 2>/dev/null || echo "unknown")
        src=$(echo "$mount" | jq -r '.Source' 2>/dev/null || echo "")
        dst=$(echo "$mount" | jq -r '.Destination' 2>/dev/null || echo "")
        
        if [[ "$mount_type" == "bind" || "$mount_type" == "volume" ]] && [[ -n "$src" ]] && [[ -n "$dst" ]]; then
            mount_args="${mount_args} -v $(sh_quote "${src}:${dst}")"
        fi
    done < "$tmp_file"
    
    rm -f "$tmp_file"
    echo "$mount_args"
}

get_container_envs() {
    local container_name="$1"
    local skip_patterns="${2:-}"
    local tmp_file
    tmp_file=$(mktemp)
    
    docker inspect "$container_name" --format='{{range .Config.Env}}{{println .}}{{end}}' > "$tmp_file"
    
    local env_args=""
    while IFS= read -r env; do
        [[ -z "$env" ]] && continue
        
        local skip=false
        if [[ -n "$skip_patterns" ]]; then
            for pattern in $skip_patterns; do
                if [[ "$env" =~ ^${pattern}= ]]; then
                    skip=true
                    break
                fi
            done
        fi
        
        [[ "$skip" == "true" ]] && continue
        env_args="${env_args} -e $(sh_quote "${env}")"
    done < "$tmp_file"
    
    rm -f "$tmp_file"
    echo "$env_args"
}

connect_container_to_network() {
    local container_name="$1"
    local network_name="$2"
    
    local current_networks
    current_networks=$(get_container_networks "$container_name")
    
    if [[ ! "$current_networks" =~ $network_name ]]; then
        docker network connect "$network_name" "$container_name" 2>/dev/null || true
        return 0
    fi
    return 1
}

list_containers_for_proxy() {
    local exclude_pattern="${1:-nginx-proxy}"
    docker ps --format '{{.Names}}' | grep -v "$exclude_pattern" | sort
}

get_container_info() {
    local container_name="$1"
    local image ports
    image=$(docker inspect "$container_name" --format='{{.Config.Image}}' 2>/dev/null | rev | cut -d/ -f1 | rev | cut -d: -f1)
    ports=$(docker inspect "$container_name" --format='{{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null | tr -d '/tcpud' | xargs)
    echo "${image}|${ports:-n/a}"
}

stop_container() {
    local container_name="$1"
    docker stop "$container_name" >/dev/null 2>&1 || true
}

start_container() {
    local container_name="$1"
    docker start "$container_name" >/dev/null 2>&1 || true
}

remove_container() {
    local container_name="$1"
    docker rm -f "$container_name" >/dev/null 2>&1 || true
}

rename_container() {
    local old_name="$1"
    local new_name="$2"
    docker rename "$old_name" "$new_name" >/dev/null 2>&1
}

wait_for_container() {
    local container_name="$1"
    local timeout="${2:-20}"
    local i
    
    for ((i=1; i<=timeout; i++)); do
        if is_container_running "$container_name"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

get_container_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    docker logs "$container_name" 2>&1 | tail -n "$lines"
}
