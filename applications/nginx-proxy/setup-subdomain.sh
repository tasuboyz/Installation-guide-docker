#!/bin/bash

# Subdomain Configuration Script for Nginx Proxy
# Automated: sets up subdomain + SSL for any service with minimal user input
# Usage: sudo ./setup-subdomain.sh [--subdomain <host>] [--container <name>] [--port <port>] [--yes]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

usage() {
    cat <<EOF
Usage: sudo ./setup-subdomain.sh [options]

Options:
  --subdomain, -s <host>   Fully qualified subdomain (eg. n8n.example.com)
  --container, -c <name>   Docker container name to configure
  --port, -p <port>        Internal port (auto-detected if omitted)
  --backend, -b <url>      Backend URL (eg. http://container:5678 or IP:port)
  --yes, -y                Non-interactive mode
  --help, -h               Show this help
EOF
}

# Parse CLI args
SUBDOMAIN=""
CONTAINER_NAME=""
INTERNAL_PORT=""
BACKEND_URL=""
AUTO_CONFIRM=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --subdomain|-s) SUBDOMAIN="$2"; shift 2;;
        --container|-c) CONTAINER_NAME="$2"; shift 2;;
        --port|-p) INTERNAL_PORT="$2"; shift 2;;
        --backend|-b) BACKEND_URL="$2"; shift 2;;
        --yes|-y) AUTO_CONFIRM=1; shift;;
        --help|-h) usage; exit 0;;
        *) print_error "Unknown option: $1"; usage; exit 1;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with root privileges. Use: sudo ./setup-subdomain.sh"
    exit 1
fi

# Check if nginx-proxy is running
if ! docker ps --format '{{.Names}}' | grep -q "^nginx-proxy$"; then
    print_error "nginx-proxy is not running. Please run ./install.sh first"
    exit 1
fi

print_header "Subdomain Configuration for Nginx Proxy"

# Get Let's Encrypt email from .env
if [[ -f .env ]]; then
    source .env
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    print_error "LETSENCRYPT_EMAIL not found in .env file. Run ./install.sh first."
    exit 1
fi

# Get Docker network from .env
DOCKER_NETWORK=${DOCKER_NETWORK:-glpi-net}

# List running services (exclude nginx-proxy)
echo ""
print_status "Running Docker containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -v "nginx-proxy" || echo "  (no containers found)"
echo ""

# Interactive: select container if not provided
if [[ -z "$CONTAINER_NAME" ]]; then
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_error "--container required in non-interactive mode"; exit 1
    fi
    read -p "Enter the container name to configure: " CONTAINER_NAME
fi

# Check if container exists
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    print_error "Container '${CONTAINER_NAME}' is not running"
    exit 1
fi

# Get subdomain if not provided
if [[ -z "$SUBDOMAIN" ]]; then
    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print_error "--subdomain required in non-interactive mode"; exit 1
    fi
    read -p "Enter the subdomain (e.g., n8n.example.com): " SUBDOMAIN
fi

# Validate domain format
if [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain format: $SUBDOMAIN"
    exit 1
fi

# DNS check (best-effort)
print_status "Checking DNS resolution for ${SUBDOMAIN}..."
if command -v dig &> /dev/null; then
    DIG_OUT=$(dig +short "$SUBDOMAIN" A 2>/dev/null || true)
    if [[ -z "$DIG_OUT" ]]; then
        print_warning "No A record found. DNS may not be configured yet."
    else
        print_status "DNS resolves to: $(echo "$DIG_OUT" | tr '\n' ' ')"
    fi
elif command -v nslookup &> /dev/null; then
    if nslookup "$SUBDOMAIN" &>/dev/null; then
        print_status "DNS resolution OK"
    else
        print_warning "DNS resolution failed. Configure DNS before requesting SSL certificate."
    fi
fi

# Port detection/selection
if [[ -z "$INTERNAL_PORT" && -z "$BACKEND_URL" ]]; then
    print_status "Detecting exposed ports for container: ${CONTAINER_NAME}"
    
    # Get all exposed ports from container
    EXPOSED_PORTS=$(docker inspect "$CONTAINER_NAME" --format='{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' 2>/dev/null || echo "")
    
    if [[ -n "$EXPOSED_PORTS" ]]; then
        # Clean up ports (remove /tcp, /udp)
        PORTS_CLEAN=$(echo "$EXPOSED_PORTS" | tr ' ' '\n' | sed 's|/.*||' | sort -n | uniq)
        PORTS_ARRAY=($PORTS_CLEAN)
        
        print_status "Exposed ports found: ${PORTS_CLEAN//$'\n'/ }"
        
        if [[ $AUTO_CONFIRM -eq 0 ]]; then
            echo ""
            echo "Select port:"
            select PORT_CHOICE in "${PORTS_ARRAY[@]}" "Enter manually"; do
                if [[ "$PORT_CHOICE" == "Enter manually" ]]; then
                    read -p "Enter port number: " INTERNAL_PORT
                    break
                elif [[ -n "$PORT_CHOICE" ]]; then
                    INTERNAL_PORT="$PORT_CHOICE"
                    break
                fi
            done
        else
            # Auto-select first port
            INTERNAL_PORT="${PORTS_ARRAY[0]}"
            print_status "Auto-selected port: ${INTERNAL_PORT}"
        fi
    else
        print_warning "No exposed ports detected"
        if [[ $AUTO_CONFIRM -eq 0 ]]; then
            read -p "Enter internal port manually: " INTERNAL_PORT
        else
            print_error "Cannot auto-detect port in non-interactive mode. Use --port"
            exit 1
        fi
    fi
fi

# Build backend URL if not provided
if [[ -z "$BACKEND_URL" ]]; then
    BACKEND_URL="http://${CONTAINER_NAME}:${INTERNAL_PORT}"
fi

# Confirm configuration
echo ""
print_header "Configuration Summary"
echo "Container:    ${CONTAINER_NAME}"
echo "Subdomain:    ${SUBDOMAIN}"
echo "Backend:      ${BACKEND_URL}"
echo "SSL Email:    ${LETSENCRYPT_EMAIL}"
echo "Network:      ${DOCKER_NETWORK}"
echo ""

if [[ $AUTO_CONFIRM -eq 0 ]]; then
    read -p "Apply this configuration? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        print_status "Configuration cancelled"
        exit 0
    fi
fi

# Check if container is connected to the proxy network
CONTAINER_NETWORKS=$(docker inspect "$CONTAINER_NAME" --format='{{range $net,$v := .NetworkSettings.Networks}}{{$net}} {{end}}')
if [[ ! "$CONTAINER_NETWORKS" =~ $DOCKER_NETWORK ]]; then
    print_warning "Container not connected to ${DOCKER_NETWORK}. Connecting now..."
    docker network connect "$DOCKER_NETWORK" "$CONTAINER_NAME" 2>/dev/null || {
        print_warning "Could not connect (container may already be on the network)"
    }
fi

# Apply configuration: set environment variables for nginx-proxy discovery
print_status "Applying configuration to container..."

# Stop container
docker stop "$CONTAINER_NAME" >/dev/null

# Add/update labels and env (we'll use labels which persist better)
docker container update \
    --label "VIRTUAL_HOST=${SUBDOMAIN}" \
    --label "VIRTUAL_PORT=${INTERNAL_PORT}" \
    --label "LETSENCRYPT_HOST=${SUBDOMAIN}" \
    --label "LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}" \
    "$CONTAINER_NAME" 2>/dev/null || {
    print_warning "Labels not updated (may require docker-compose recreation)"
}

# Restart container
print_status "Restarting container..."
docker start "$CONTAINER_NAME" >/dev/null

# Alternative: if container was started via docker-compose, recreate it with new config
# Check if there's a docker-compose file associated
COMPOSE_PROJECT=$(docker inspect "$CONTAINER_NAME" --format='{{index .Config.Labels "com.docker.compose.project"}}' 2>/dev/null || echo "")
if [[ -n "$COMPOSE_PROJECT" ]]; then
    COMPOSE_FILE=$(docker inspect "$CONTAINER_NAME" --format='{{index .Config.Labels "com.docker.compose.project.working_dir"}}' 2>/dev/null || echo "")
    if [[ -n "$COMPOSE_FILE" && -d "$COMPOSE_FILE" ]]; then
        print_status "Detected docker-compose project. Generating override configuration..."
        
        OVERRIDE_FILE="${COMPOSE_FILE}/docker-compose.${CONTAINER_NAME}.override.yml"
        SERVICE_NAME=$(docker inspect "$CONTAINER_NAME" --format='{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null || echo "$CONTAINER_NAME")
        
        cat > "$OVERRIDE_FILE" << EOF
# Auto-generated nginx-proxy configuration for ${SERVICE_NAME}
# Merge this into your docker-compose.yml or use as override

services:
  ${SERVICE_NAME}:
    environment:
      - VIRTUAL_HOST=${SUBDOMAIN}
      - VIRTUAL_PORT=${INTERNAL_PORT}
      - LETSENCRYPT_HOST=${SUBDOMAIN}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
    networks:
      - ${DOCKER_NETWORK}
    expose:
      - "${INTERNAL_PORT}"

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF
        
        print_status "Override file created: ${OVERRIDE_FILE}"
        print_warning "To apply permanently, merge this config into your docker-compose.yml"
        print_warning "Then run: cd ${COMPOSE_FILE} && docker compose up -d ${SERVICE_NAME}"
    fi
fi

print_status "Configuration applied successfully!"

# Wait for acme-companion to process
print_status "Waiting for SSL certificate issuance..."
echo ""
print_status "This can take 1-3 minutes. Monitoring acme-companion logs..."
echo ""

sleep 5

# Tail logs briefly to show progress
timeout 30 docker logs -f nginx-proxy-acme 2>&1 | grep -i "$SUBDOMAIN" || {
    print_status "Certificate request in progress (check logs if needed)"
}

echo ""
print_header "Setup Complete!"
print_status "Service configuration:"
print_status "  Container:  ${CONTAINER_NAME}"
print_status "  URL:        https://${SUBDOMAIN}"
print_status "  Backend:    ${BACKEND_URL}"
echo ""
print_status "Test your endpoint:"
echo "  curl -I https://${SUBDOMAIN}"
echo ""
print_status "Monitor certificate issuance:"
echo "  docker logs -f nginx-proxy-acme"
echo ""
print_status "Check nginx proxy status:"
echo "  docker exec nginx-proxy nginx -t"
echo "  docker logs nginx-proxy | tail -20"
echo ""

if [[ -n "$COMPOSE_PROJECT" ]]; then
    print_warning "For persistent configuration, update your docker-compose.yml with the generated override"
fi