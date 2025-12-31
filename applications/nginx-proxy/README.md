# Nginx Reverse Proxy + SSL Automatico

Setup automatizzato completo di nginx-proxy con certificati SSL Let's Encrypt.

## Quick Start

```bash
# UN SOLO COMANDO FA TUTTO!
chmod +x install.sh
sudo ./install.sh
```

Lo script ti guida attraverso 8 step:
1. **Rete Docker** - usa esistente o crea nuova
2. **Email** - per notifiche Let's Encrypt
3. **Modalità SSL** - staging (test) o produzione
4. **Avvio proxy** - nginx-proxy + acme-companion
5. **Container** - selezione da lista
6. **Sottodominio** - il dominio completo da usare (es: n8n.tuodominio.com)
7. **Porta** - auto-rilevata o manuale
8. **Conferma** - riepilogo e applicazione

## Esempio Completo

```bash
sudo ./install.sh

# ╔═══════════════════════════════════════════════════════════════╗
# ║     NGINX REVERSE PROXY + SSL AUTOMATICO                      ║
# ╚═══════════════════════════════════════════════════════════════╝

# STEP 1/8 - Rete Docker
# Reti Docker esistenti:
#   • glpi-net
# Nome rete Docker [default: glpi-net]: ↵

# STEP 2/8 - Email Let's Encrypt
# Email per Let's Encrypt: admin@example.com

# STEP 3/8 - Modalità SSL
#   1) PRODUZIONE - certificati validi
#   2) STAGING    - certificati test
# Scegli [1/2, default: 1]: ↵

# STEP 4/8 - Avvio Nginx Proxy
# [✓] nginx-proxy attivo
# [✓] acme-companion attivo

# STEP 5/8 - Seleziona Container da Esporre
# Container disponibili:
#    1) n8n                       [n8n] ports: 5678
#    2) chatwoot_rails_1          [chatwoot] ports: 3000
# Seleziona [1-2]: 1

# STEP 6/8 - Sottodominio
# Inserisci il sottodominio COMPLETO che vuoi usare per n8n
# Esempi:
#   • n8n.tuodominio.com
#   • chat.example.org
# Sottodominio: n8n.miodominio.com

# STEP 7/8 - Porta Interna
# Porta rilevata: 5678
# Usare questa porta? [Y/n]: ↵

# STEP 8/8 - Riepilogo
#   Container:     n8n
#   Sottodominio:  n8n.miodominio.com
#   Porta:         5678
#   Email:         admin@example.com
#   Rete:          glpi-net
#   Modalità:      PRODUZIONE
# Procedo con la configurazione? [Y/n]: ↵

# ╔═══════════════════════════════════════════════════════════════╗
# ║                    CONFIGURAZIONE COMPLETATA                  ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# AZIONE RICHIESTA: Aggiungi al docker-compose.yml del servizio:
#   environment:
#     - VIRTUAL_HOST=n8n.miodominio.com
#     - LETSENCRYPT_HOST=n8n.miodominio.com
#     ...
#
# Poi: docker compose up -d

# Configurare un altro servizio? [y/N]: 
```

## Struttura File

```
nginx-proxy/
├── docker-compose.yml      # Config nginx-proxy + acme-companion
├── .env                    # Generato automaticamente dallo script
├── install.sh              # ⭐ SCRIPT PRINCIPALE - fa tutto
├── setup-subdomain.sh      # Utility alternativa (standalone)
└── configs/                # Configurazioni generate per ogni servizio
```

## Staging vs Produzione

| Modalità | Certificati | Limite | Browser |
|----------|-------------|--------|---------|
| **Produzione** | Validi | 5/settimana per dominio | ✓ Fidati |
| **Staging** | Test | Illimitati | ✗ Non fidati |

Usa staging per test/debug, poi produzione quando tutto funziona.

## Dopo lo Script

Lo script ti dice esattamente cosa aggiungere al docker-compose del tuo servizio:

```yaml
services:
  n8n:
    # ... config esistente ...
    environment:
      - VIRTUAL_HOST=n8n.miodominio.com
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=n8n.miodominio.com
      - LETSENCRYPT_EMAIL=admin@example.com
    networks:
      - glpi-net

networks:
  glpi-net:
    external: true
```

Poi riavvia il servizio:
```bash
docker compose up -d
```

Il certificato viene emesso automaticamente in 1-2 minuti.

## Troubleshooting

```bash
# Log certificati (utile per debug)
docker logs nginx-proxy-acme -f

# Test config nginx
docker exec nginx-proxy nginx -t

# Verifica rete
docker network inspect glpi-net

# Aggiungi altri servizi
sudo ./install.sh   # Rieseguibile per configurare più servizi
```

## Caratteristiche

- **Auto-detect porte**: rileva automaticamente le porte esposte dai container
- **DNS check**: verifica che il DNS sia configurato correttamente
- **WebSocket ready**: configurato per applicazioni real-time
- **Log rotati**: evita consumo eccessivo di disco
- **Rieseguibile**: puoi aggiungere servizi multipli
