#!/bin/bash

# Nginx Reverse Proxy + Certbot SSL Installation Script
# This script sets up nginx-proxy with automatic SSL certificate management
# Run with: sudo ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run with root privileges. Use: sudo ./install.sh"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please install Docker Compose."
    exit 1
fi

print_header "Nginx Reverse Proxy + SSL Installation"

# Check if glpi-net network exists
if ! docker network ls | grep -q "glpi-net"; then
    print_warning "Network 'glpi-net' does not exist. Creating it now..."
    docker network create glpi-net
    print_status "Network 'glpi-net' created successfully"
else
    print_status "Network 'glpi-net' already exists"
fi

# Get Let's Encrypt email
if [[ -f .env ]]; then
    source .env
fi

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
    echo ""
    read -p "Enter your email for Let's Encrypt notifications: " LETSENCRYPT_EMAIL
    
    # Validate email format
    if [[ ! "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Invalid email format"
        exit 1
    fi
    
    # Create .env file
    echo "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL" > .env
    print_status "Created .env file with email: $LETSENCRYPT_EMAIL"
fi

# Check if nginx-proxy is already running
if docker ps | grep -q "nginx-proxy"; then
    print_warning "nginx-proxy is already running"
    read -p "Do you want to restart it? (y/n): " RESTART
    if [[ "$RESTART" == "y" ]]; then
        docker compose down
    else
        print_status "Keeping existing nginx-proxy running"
        exit 0
    fi
fi

# Start nginx-proxy
print_status "Starting nginx-proxy and acme-companion..."
docker compose up -d

# Wait for containers to be healthy
print_status "Waiting for containers to start..."
sleep 5

# Check if containers are running
if docker ps | grep -q "nginx-proxy" && docker ps | grep -q "nginx-proxy-acme"; then
    print_status "✓ nginx-proxy is running"
    print_status "✓ acme-companion is running"
else
    print_error "Failed to start one or more containers"
    docker compose logs
    exit 1
fi

print_header "Installation Complete!"
echo ""
print_status "Nginx reverse proxy is now running on:"
print_status "  - HTTP:  port 80"
print_status "  - HTTPS: port 443"
echo ""
print_warning "Next steps:"
echo "  1. Configure your services to use the proxy (add labels to docker-compose)"
echo "  2. Use ./setup-subdomain.sh to configure subdomains"
echo "  3. Ensure DNS records point to this server"
echo ""
print_status "Example service configuration:"
echo "  environment:"
echo "    - VIRTUAL_HOST=myapp.example.com"
echo "    - LETSENCRYPT_HOST=myapp.example.com"
echo "    - LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL"
echo "  networks:"
echo "    - glpi-net"
echo ""
print_status "Check logs with: docker compose logs -f"
print_status "View certificates: ls -la /var/lib/docker/volumes/nginx-proxy_nginx-certs/_data/"
