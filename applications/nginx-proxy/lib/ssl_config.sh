#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ACME_STAGING_URI="https://acme-staging-v02.api.letsencrypt.org/directory"

get_acme_uri() {
    local mode="${1:-production}"
    if [[ "$mode" == "staging" || "$mode" == "2" ]]; then
        echo "$ACME_STAGING_URI"
    else
        echo ""
    fi
}

is_staging_mode() {
    local acme_uri="${1:-}"
    [[ -n "$acme_uri" ]]
}

generate_env_file() {
    local email="$1"
    local network="$2"
    local acme_uri="${3:-}"
    local env_file="${4:-.env}"
    
    cat > "$env_file" << EOF
LETSENCRYPT_EMAIL=${email}
DOCKER_NETWORK=${network}
EOF
    
    if [[ -n "$acme_uri" ]]; then
        echo "ACME_CA_URI=${acme_uri}" >> "$env_file"
    fi
    
    print_status ".env generato"
}

check_dns_resolution() {
    local domain="$1"
    local dns_result=""
    
    if command -v dig &> /dev/null; then
        dns_result=$(dig +short "$domain" A 2>/dev/null | head -1 || echo "")
    elif command -v nslookup &> /dev/null; then
        dns_result=$(nslookup "$domain" 2>/dev/null | awk '/^Address: /{print $2}' | head -1 || echo "")
    fi
    
    if [[ -n "$dns_result" ]]; then
        print_status "DNS: $dns_result"
        echo "$dns_result"
        return 0
    else
        print_warning "DNS non configurato - configuralo prima di richiedere il certificato"
        return 1
    fi
}

get_public_ip() {
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo ""
}

check_domain_reachable() {
    local domain="$1"
    local public_ip
    public_ip=$(get_public_ip)
    
    local dns_ips=""
    if command -v dig &> /dev/null; then
        dns_ips=$(dig +short A "$domain" 2>/dev/null | tr '\n' ' ')
    elif command -v nslookup &> /dev/null; then
        dns_ips=$(nslookup -type=A "$domain" 2>/dev/null | awk '/^Address: /{print $2}' | tr '\n' ' ')
    fi
    
    for ip in $dns_ips; do
        if [[ "$ip" == "$public_ip" ]]; then
            return 0
        fi
    done
    
    if command -v curl &> /dev/null; then
        if curl -sSL --max-time 5 "http://${domain}/.well-known/acme-challenge/" >/dev/null 2>&1; then
            return 0
        fi
    fi
    
    return 1
}

wait_for_certificate() {
    local domain="$1"
    local timeout="${2:-120}"
    local interval=5
    local waited=0
    
    print_status "Attesa emissione certificato per ${domain}..."
    
    while ((waited < timeout)); do
        if docker exec nginx-proxy-acme ls "/etc/nginx/certs/${domain}.crt" &>/dev/null; then
            print_status "Certificato emesso per ${domain}"
            return 0
        fi
        sleep $interval
        waited=$((waited + interval))
    done
    
    print_warning "Timeout attesa certificato. Controlla i log: docker logs nginx-proxy-acme"
    return 1
}

monitor_acme_logs() {
    local domain="$1"
    local timeout="${2:-30}"
    
    print_status "Monitoraggio log acme-companion..."
    timeout "$timeout" docker logs -f nginx-proxy-acme 2>&1 | grep -i "$domain" || true
}

print_ssl_instructions() {
    local domain="$1"
    local is_staging="${2:-false}"
    
    echo ""
    echo "Monitoraggio certificato SSL:"
    echo "  docker logs -f nginx-proxy-acme"
    echo ""
    echo "Il certificato verrà emesso automaticamente in 1-2 minuti."
    echo "Controlla i log per confermare:"
    echo "  docker logs nginx-proxy-acme 2>&1 | grep '${domain}'"
    echo ""
    echo "Test rapido dopo 1-2 min:"
    echo "  curl -I https://${domain}"
    echo ""
    
    if [[ "$is_staging" == "true" ]]; then
        print_warning "ATTENZIONE: Modalità STAGING attiva"
        print_warning "Il certificato NON sarà valido per i browser"
        echo ""
    fi
}
