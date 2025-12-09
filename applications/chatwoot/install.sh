#!/bin/bash

# Chatwoot Installation Script
# This script automates the installation of Chatwoot using Docker Compose
# Run with: sudo ./install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

print_status "Starting Chatwoot installation..."

# Create installation directory if not exists
INSTALL_DIR="$(pwd)"
print_status "Installation directory: $INSTALL_DIR"

# Download configuration files
print_status "Downloading configuration files..."
wget -O .env https://raw.githubusercontent.com/chatwoot/chatwoot/develop/.env.example
wget -O docker-compose.yaml https://raw.githubusercontent.com/chatwoot/chatwoot/develop/docker-compose.production.yaml

# Generate SECRET_KEY_BASE
SECRET_KEY_BASE=$(openssl rand -hex 64)
sed -i "s|SECRET_KEY_BASE=.*|SECRET_KEY_BASE=$SECRET_KEY_BASE|g" .env

# Set RAILS_ENV to production
sed -i "s|RAILS_ENV=.*|RAILS_ENV=production|g" .env

# Prompt for domain/frontend URL
read -p "Enter your domain (e.g., chat.yourdomain.com): " DOMAIN
if [[ -n "$DOMAIN" ]]; then
    sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|g" .env
else
    print_warning "No domain provided. You can configure FRONTEND_URL later in .env"
fi

# Generate random passwords for Postgres and Redis
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)

# Update .env with passwords
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" .env
sed -i "s|REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PASSWORD|g" .env

# Update docker-compose.yaml with same passwords
sed -i "s|POSTGRES_PASSWORD:.*|POSTGRES_PASSWORD: $POSTGRES_PASSWORD|g" docker-compose.yaml
sed -i "s|REDIS_PASSWORD:.*|REDIS_PASSWORD: $REDIS_PASSWORD|g" docker-compose.yaml

print_status "Configuration files downloaded and configured."

# Prepare the database
print_status "Preparing the database..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

# Start the services
print_status "Starting Chatwoot services..."
docker compose up -d

print_status "Chatwoot installation completed!"
print_status "Access your installation at: http://<server-ip>:3000 (or http://localhost:3000 on the server)"
print_status "If you want LAN access, set FRONTEND_URL in .env to your server LAN IP (e.g. http://192.168.1.42:3000)"
if [[ -n "$DOMAIN" ]]; then
    print_status "Configure Nginx proxy for domain: $DOMAIN"
    print_status "See: https://developers.chatwoot.com/self-hosted/deployment/docker#configure-nginx-and-lets-encrypt"
fi

print_warning "Remember to:"
print_warning "- Set up a reverse proxy (Nginx) for production"
print_warning "- Configure SSL certificates"
print_warning "- Update email settings in .env if needed"
print_warning "- Use cloud storage for attachments in production"