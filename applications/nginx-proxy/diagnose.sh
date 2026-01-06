#!/bin/bash

set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         DIAGNOSTICA NGINX-PROXY + CHATWOOT                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

ISSUES=0
WARNINGS=0

print_ok() {
    echo "  ✅ $1"
}

print_error() {
    echo "  ❌ $1"
    ((ISSUES++))
}

print_warning() {
    echo "  ⚠️  $1"
    ((WARNINGS++))
}

print_info() {
    echo "  ℹ️  $1"
}

# ============================================================================
echo "1️⃣  CONTAINER STATUS"
echo "─────────────────────────────────────────────────────────────────────"

if docker ps | grep -q "nginx-proxy.*Up"; then
    print_ok "nginx-proxy è ONLINE"
else
    print_error "nginx-proxy NON è in esecuzione"
fi

if docker ps | grep -q "nginx-proxy-acme.*Up"; then
    print_ok "acme-companion è ONLINE"
else
    print_error "acme-companion NON è in esecuzione"
fi

if docker ps | grep -q "chatwoot-rails.*Up"; then
    print_ok "chatwoot-rails è ONLINE"
else
    print_error "chatwoot-rails NON è in esecuzione"
fi

echo ""

# ============================================================================
echo "2️⃣  RETE DOCKER"
echo "─────────────────────────────────────────────────────────────────────"

if docker network inspect n8n-net >/dev/null 2>&1; then
    print_ok "Rete 'n8n-net' trovata"
    
    if docker network inspect n8n-net | grep -q "nginx-proxy"; then
        print_ok "nginx-proxy è collegato a 'n8n-net'"
    else
        print_error "nginx-proxy NON è collegato a 'n8n-net'"
    fi
    
    if docker network inspect n8n-net | grep -q "chatwoot-rails"; then
        print_ok "chatwoot-rails è collegato a 'n8n-net'"
    else
        print_error "chatwoot-rails NON è collegato a 'n8n-net'"
    fi
else
    print_error "Rete 'n8n-net' NON trovata"
fi

echo ""

# ============================================================================
echo "3️⃣  CONNETTIVITÀ INTERNA"
echo "─────────────────────────────────────────────────────────────────────"

if docker ps | grep -q "nginx-proxy.*Up"; then
    if docker exec nginx-proxy curl -sf http://chatwoot-rails-1:3000/ >/dev/null 2>&1; then
        print_ok "nginx-proxy può raggiungere chatwoot-rails-1:3000"
    else
        print_error "nginx-proxy NON può raggiungere chatwoot-rails-1:3000"
        print_info "Controllare: docker logs nginx-proxy"
    fi
fi

echo ""

# ============================================================================
echo "4️⃣  CERTIFICATI SSL"
echo "─────────────────────────────────────────────────────────────────────"

if docker exec nginx-proxy test -f /etc/nginx/certs/chatwoot.tasuthor.com.crt 2>/dev/null; then
    print_ok "Certificato SSL per chatwoot.tasuthor.com trovato"
    
    EXPIRY=$(docker exec nginx-proxy openssl x509 -enddate -noout -in /etc/nginx/certs/chatwoot.tasuthor.com.crt 2>/dev/null | cut -d= -f2 || echo "N/A")
    print_info "Scadenza: $EXPIRY"
else
    print_warning "Certificato SSL per chatwoot.tasuthor.com NON trovato"
    print_info "Attendi 1-2 minuti che acme-companion emetta il certificato"
fi

echo ""

# ============================================================================
echo "5️⃣  CONFIGURAZIONE NGINX"
echo "─────────────────────────────────────────────────────────────────────"

if docker exec nginx-proxy test -f /etc/nginx/vhost.d/chatwoot.tasuthor.com 2>/dev/null; then
    print_ok "Vhost config per chatwoot.tasuthor.com trovato"
    
    VHOST_CONFIG=$(docker exec nginx-proxy cat /etc/nginx/vhost.d/chatwoot.tasuthor.com)
    
    if echo "$VHOST_CONFIG" | grep -q "proxy_pass_request_headers"; then
        print_ok "proxy_pass_request_headers è configurato"
    else
        print_warning "proxy_pass_request_headers NON è configurato"
    fi
    
    if echo "$VHOST_CONFIG" | grep -q "Authorization"; then
        print_ok "Authorization header è configurato"
    else
        print_warning "Authorization header NON è configurato"
    fi
else
    print_warning "Vhost config per chatwoot.tasuthor.com NON trovato"
    print_info "Esegui: sudo ./add-service.sh"
fi

echo ""

# ============================================================================
echo "6️⃣  CONFIGURAZIONE CHATWOOT"
echo "─────────────────────────────────────────────────────────────────────"

# Leggi le configurazioni salvate
if [[ -f "configs/chatwoot-rails.conf" ]]; then
    source configs/chatwoot-rails.conf
    print_ok "Configurazione salvata trovata"
    print_info "Container: $CONTAINER"
    print_info "Sottodominio: $SUBDOMAIN"
    print_info "Porta: $PORT"
else
    print_warning "Configurazione salvata NON trovata"
    print_info "Esegui: sudo ./add-service.sh"
fi

echo ""

# ============================================================================
echo "7️⃣  TEST SINTASSI NGINX"
echo "─────────────────────────────────────────────────────────────────────"

if docker exec nginx-proxy nginx -t 2>&1 | grep -q "successful"; then
    print_ok "Configurazione nginx è valida"
else
    print_error "Configurazione nginx ha errori"
    docker exec nginx-proxy nginx -t 2>&1 | head -20
fi

echo ""

# ============================================================================
echo "8️⃣  LOG DIAGNOSTICA"
echo "─────────────────────────────────────────────────────────────────────"

echo ""
echo "📄 Ultimi 20 log nginx-proxy:"
echo "─────────────────────────────────────────────────────────────────────"
docker logs --tail 20 nginx-proxy 2>&1 | tail -20

echo ""
echo "📄 Ultimi 20 log acme-companion:"
echo "─────────────────────────────────────────────────────────────────────"
docker logs --tail 20 nginx-proxy-acme 2>&1 | tail -20

echo ""

# ============================================================================
echo "9️⃣  RIEPILOGO PROBLEMI"
echo "─────────────────────────────────────────────────────────────────────"

if [[ $ISSUES -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo "✅ Nessun problema rilevato!"
    echo ""
    echo "Test API di Chatwoot:"
    echo ""
    echo "  curl --request GET \\"
    echo "    --url 'https://chatwoot.tasuthor.com/api/v1/accounts/1/contacts?page=1' \\"
    echo "    --header 'Authorization: Bearer YOUR_TOKEN'"
    echo ""
elif [[ $ISSUES -eq 0 ]]; then
    echo "⚠️  $WARNINGS avvisi (controllare sopra)"
else
    echo "❌ $ISSUES problemi rilevati (controllare sopra)"
    echo ""
    echo "💡 Suggerimenti:"
    echo ""
    echo "   1. Se nginx-proxy è offline:"
    echo "      docker logs nginx-proxy | tail -50"
    echo ""
    echo "   2. Se chatwoot non è configurato:"
    echo "      sudo ./add-service.sh"
    echo ""
    echo "   3. Se il certificato non è stato emesso:"
    echo "      docker logs nginx-proxy-acme | grep chatwoot"
    echo ""
    echo "   4. Reset completo:"
    echo "      docker compose down"
    echo "      docker volume rm nginx-certs nginx-vhost nginx-html acme-state"
    echo "      sudo ./setup.sh"
fi

echo ""
