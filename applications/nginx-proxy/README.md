# Nginx Reverse Proxy + SSL Automatico

Setup COMPLETAMENTE AUTOMATIZZATO di nginx-proxy con certificati SSL Let's Encrypt.

## Quick Start

```bash
chmod +x install.sh
sudo ./install.sh
```

**Lo script fa TUTTO automaticamente:**
1. Configura rete Docker
2. Configura email Let's Encrypt
3. Avvia nginx-proxy + acme-companion
4. Chiede quale container esporre
5. Chiede il sottodominio
6. Rileva la porta automaticamente
7. **Riconfigura il container** con le variabili SSL
8. **Il servizio è raggiungibile via HTTPS in 1-2 minuti**

**NESSUN INTERVENTO MANUALE RICHIESTO** — niente modifiche a docker-compose, niente comandi extra, niente configurazioni manuali.

## Esempio Completo

```bash
sudo ./install.sh

# ╔═══════════════════════════════════════════════════════════════╗
# ║     NGINX REVERSE PROXY + SSL AUTOMATICO                      ║
# ╚═══════════════════════════════════════════════════════════════╝

# STEP 1/8 - Rete Docker
# Nome rete Docker [default: glpi-net]: n8n-net ↵

# STEP 2/8 - Email Let's Encrypt
# Email per Let's Encrypt: admin@example.com ↵

# STEP 3/8 - Modalità SSL
#   1) PRODUZIONE - certificati validi
#   2) STAGING    - certificati test
# Scegli [1/2, default: 1]: 1 ↵

# STEP 4/8 - Avvio Nginx Proxy
# [✓] nginx-proxy attivo
# [✓] acme-companion attivo

# STEP 5/8 - Seleziona Container da Esporre
# Container disponibili:
#    1) n8n                       [n8n] ports: 5678
#    2) chatwoot_rails_1          [chatwoot] ports: 3000
# Seleziona [1-2]: 1 ↵

# STEP 6/8 - Sottodominio
# Sottodominio: n8n.miodominio.com ↵
# [✓] DNS: 207.154.252.110

# STEP 7/8 - Porta Interna
# Porta rilevata: 5678
# Usare questa porta? [Y/n]: ↵

# STEP 8/8 - Applicazione Automatica
# Procedo con la configurazione automatica? [Y/n]: ↵
#
#   → Connessione a rete n8n-net...
#   → Ricreazione container con configurazione SSL...
#
# ╔═══════════════════════════════════════════════════════════════╗
# ║               CONFIGURAZIONE COMPLETATA CON SUCCESSO          ║
# ╚═══════════════════════════════════════════════════════════════╝
#
# Il servizio n8n è ora configurato per:
#   https://n8n.miodominio.com
#
# Il certificato verrà emesso automaticamente in 1-2 minuti.
```

## Come Funziona

Lo script:
- **Non tocca i docker-compose** dei tuoi servizi
- **Ricrea automaticamente** il container selezionato preservando:
  - Immagine Docker
  - Volumi (bind mounts e named volumes)
  - Environment variables
  - Command ed entrypoint
- **Aggiunge** le variabili necessarie per nginx-proxy:
  - `VIRTUAL_HOST=tuo.dominio.com`
  - `VIRTUAL_PORT=5678`
  - `LETSENCRYPT_HOST=tuo.dominio.com`
  - `LETSENCRYPT_EMAIL=tua@email.com`
- **acme-companion** rileva automaticamente il container e richiede il certificato SSL
- **Tutto persiste** tramite volumi Docker (riavvii, aggiornamenti, ecc.)

## Staging vs Produzione

| Modalità | Certificati | Limite | Browser |
|----------|-------------|--------|---------|
| **Produzione** | Validi | 5/settimana per dominio | ✓ Fidati |
| **Staging** | Test | Illimitati | ✗ Non fidati |

**Consiglio:** usa staging per test, poi produzione quando tutto funziona.

## Configurare Altri Servizi

Riesegui lo script:
```bash
sudo ./install.sh
```

Lo script riconosce che il proxy è già attivo e ti chiede direttamente quale altro servizio configurare.

## Monitoraggio

```bash
# Log certificati (in tempo reale)
docker logs -f nginx-proxy-acme

# Cerca certificato specifico
docker logs nginx-proxy-acme 2>&1 | grep 'n8n.miodominio.com'

# Test HTTPS (dopo 1-2 minuti)
curl -I https://n8n.miodominio.com
```

## Troubleshooting

### Certificato non emesso dopo 5 minuti

```bash
# Controlla log per errori
docker logs nginx-proxy-acme

# Verifica DNS
dig +short n8n.miodominio.com

# Verifica che il container abbia le env corrette
docker inspect n8n | grep -A5 Env
```

### Servizio non raggiungibile

```bash
# Verifica nginx
docker logs nginx-proxy

# Test config nginx
docker exec nginx-proxy nginx -t

# Verifica rete
docker network inspect n8n-net
```

### Ripartire da zero

```bash
# Ferma tutto
docker compose down

# Rimuovi volumi (ATTENZIONE: perdi certificati)
docker volume rm nginx-certs nginx-vhost nginx-html acme-state

# Riavvia
sudo ./install.sh
```

## Struttura File

```
nginx-proxy/
├── docker-compose.yml      # nginx-proxy + acme-companion
├── custom-nginx.conf       # Configurazione globale nginx
├── .env                    # Generato automaticamente
├── install.sh              # ⭐ SCRIPT PRINCIPALE
├── configs/                # Backup configurazioni servizi
└── vhost-configs/          # Configurazioni vhost (non usato con acme-companion)
```

## Caratteristiche

- ✅ **Zero configurazione manuale** — tutto automatico
- ✅ **Preserva configurazione** container esistenti
- ✅ **Auto-rileva porte** esposte
- ✅ **Verifica DNS** prima di procedere
- ✅ **Certificati automatici** via Let's Encrypt
- ✅ **Rinnovo automatico** certificati (acme-companion)
- ✅ **WebSocket ready** per app real-time
- ✅ **Persistenza** via volumi Docker
- ✅ **Rieseguibile** per configurare più servizi
- ✅ **Staging mode** per test senza rate limit

## Requisiti

- Docker e Docker Compose
- Porta 80 e 443 aperte
- DNS configurato e puntato al server
- Permessi root (sudo)

## Supporto

Logs utili:
```bash
docker logs nginx-proxy          # Proxy logs
docker logs nginx-proxy-acme     # Certificate logs
docker ps                        # Containers attivi
docker network ls                # Reti disponibili
```
