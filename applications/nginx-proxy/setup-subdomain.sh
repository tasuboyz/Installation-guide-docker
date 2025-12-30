#!/bin/bash

# Subdomain Configuration Script for Nginx Proxy
# This script helps configure a service to work with nginx-proxy and automatic SSL
# Run with: sudo ./setup-subdomain.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with root privileges. Use: sudo ./setup-subdomain.sh"
    exit 1
fi

# Check if nginx-proxy is running
if ! docker ps | grep -q "nginx-proxy"; then
    print_error "nginx-proxy is not running. Please run ./install.sh first"
    exit 1
fi

print_header "Subdomain Configuration for Nginx Proxy"

# Get Let's Encrypt email from .env
if [[ -f .env ]]; then
    source .env
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    print_error "LETSENCRYPT_EMAIL not found in .env file"
    exit 1
fi

# List running services
echo ""
print_status "Running Docker containers:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}" | grep -v "nginx-proxy"
echo ""

# Get service information
read -p "Enter the container name to configure: " CONTAINER_NAME

# Check if container exists
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    print_error "Container '$CONTAINER_NAME' is not running"
    exit 1
fi

read -p "Enter the subdomain (e.g., chatwoot.example.com): " SUBDOMAIN

# Validate domain format
if [[ ! "$SUBDOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain format"
    exit 1
fi

# Optional: Check DNS resolution
print_status "Checking DNS resolution for $SUBDOMAIN..."
if host "$SUBDOMAIN" > /dev/null 2>&1; then
    IP=$(host "$SUBDOMAIN" | grep "has address" | awk '{print $4}' | head -1)
    print_status "DNS resolves to: $IP"
    
    # Get server's public IP
    SERVER_IP=$(curl -s https://api.ipify.org)
    if [[ "$IP" != "$SERVER_IP" ]]; then
        print_warning "DNS points to $IP, but server public IP is $SERVER_IP"
        print_warning "Make sure DNS is configured correctly or you're using internal DNS"
    fi
else
    print_warning "DNS resolution failed for $SUBDOMAIN"
    print_warning "Make sure to configure DNS before certificates can be issued"
fi

# Get internal port (optional)
read -p "Enter internal port (press Enter to auto-detect): " INTERNAL_PORT

if [[ -z "$INTERNAL_PORT" ]]; then
    # Try to detect port from container
    DETECTED_PORT=$(docker inspect "$CONTAINER_NAME" | grep -o '"ExposedPorts":{[^}]*}' | grep -o '[0-9]*/' | head -1 | tr -d '/')
    if [[ -n "$DETECTED_PORT" ]]; then
        INTERNAL_PORT=$DETECTED_PORT
        print_status "Auto-detected port: $INTERNAL_PORT"
    else
        print_warning "Could not auto-detect port. Using default 80"
        INTERNAL_PORT=80
    fi
fi

# Confirm configuration
echo ""
print_header "Configuration Summary"
echo "Container:    $CONTAINER_NAME"
echo "Subdomain:    $SUBDOMAIN"
echo "Port:         $INTERNAL_PORT"
echo "SSL Email:    $LETSENCRYPT_EMAIL"
echo ""

read -p "Apply this configuration? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    print_status "Configuration cancelled"
    exit 0
fi

# Generate docker-compose override snippet
OVERRIDE_FILE="${CONTAINER_NAME}-proxy-config.yml"

cat > "$OVERRIDE_FILE" << EOF
# Nginx Proxy Configuration for $CONTAINER_NAME
# Add these sections to your docker-compose.yml

services:
  $CONTAINER_NAME:
    environment:
      - VIRTUAL_HOST=$SUBDOMAIN
      - VIRTUAL_PORT=$INTERNAL_PORT
      - LETSENCRYPT_HOST=$SUBDOMAIN
      - LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
    networks:
      - glpi-net
    expose:
      - "$INTERNAL_PORT"

networks:
  glpi-net:
    external: true
EOF

print_status "Configuration saved to $OVERRIDE_FILE"

echo ""
print_header "Next Steps"
echo ""
print_status "1. Update your docker-compose.yml with the configuration from $OVERRIDE_FILE"
print_status "2. Restart the service: docker compose up -d $CONTAINER_NAME"
print_status "3. Wait 1-2 minutes for SSL certificate to be issued"
print_status "4. Access your service at: https://$SUBDOMAIN"
echo ""
print_warning "Certificate issuance can take a few minutes. Check logs with:"
echo "  docker logs nginx-proxy-acme -f"
echo ""
print_status "To verify SSL certificate:"
echo "  curl -I https://$SUBDOMAIN"
echo "  openssl s_client -connect $SUBDOMAIN:443 -servername $SUBDOMAIN"
