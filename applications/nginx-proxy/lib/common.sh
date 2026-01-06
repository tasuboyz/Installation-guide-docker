#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_status() { 
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() { 
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() { 
    echo -e "${RED}[✗]${NC} $1"
}

print_header() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_banner() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     $1${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

sh_quote() {
    local s="$1"
    s="${s//\'/\'\\\'\'}"
    printf "'%s'" "$s"
}

validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_domain() {
    local domain="$1"
    [[ -n "$domain" ]] || return 1
    [[ "$domain" =~ ^[[:space:]]*$ ]] && return 1
    [[ "$domain" =~ [[:space:]] ]] && return 1
    [[ "$domain" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Esegui con: sudo $0"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker non installato"
        exit 1
    fi
}

detect_docker_compose() {
    local dcmd=""
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        dcmd="docker compose"
    elif command -v docker-compose &> /dev/null && docker-compose version &> /dev/null; then
        dcmd="docker-compose"
    else
        print_error "Docker Compose non disponibile"
        exit 1
    fi
    echo "$dcmd"
}

to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

confirm_yes() {
    local input="$1"
    local lower
    lower=$(to_lowercase "$input")
    [[ "$lower" == "y" || "$lower" == "yes" ]]
}

confirm_no() {
    local input="$1"
    local lower
    lower=$(to_lowercase "$input")
    [[ "$lower" == "n" || "$lower" == "no" ]]
}

get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -L "$source" ]]; do
        local dir
        dir=$(cd -P "$(dirname "$source")" && pwd)
        source=$(readlink "$source")
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

load_env_file() {
    local env_file="${1:-.env}"
    if [[ -f "$env_file" ]]; then
        set -a
        source "$env_file" 2>/dev/null || true
        set +a
        return 0
    fi
    return 1
}

exit_ok() {
    exit 0
}

exit_user_error() {
    exit 1
}

exit_system_error() {
    exit 2
}
