# Nginx Reverse Proxy + SSL Automatico

Setup **flessibile e riutilizzabile** di nginx-proxy con certificati SSL Let's Encrypt automatici.

## 🚀 Quick Start

```bash
chmod +x setup.sh add-service.sh
sudo ./setup.sh
```

Lo script:
1. ✅ Crea il file `.env` con la configurazione
2. ✅ Verifica/crea la rete Docker
3. ✅ Avvia nginx-proxy e acme-companion
4. ✅ Configura i certificati SSL automatici

## 📋 Configurazione (File .env)

Il file `.env` contiene:

```bash
# Email per ricevere notifiche certificati expiring
LETSENCRYPT_EMAIL=your-email@example.com

# Rete Docker dove gira chatwoot, n8n, e altri servizi
# Esempi comuni: n8n-net, chatwoot_default, custom-network
DOCKER_NETWORK=n8n-net

# Opzionale: ACME staging URI per testing
# ACME_CA_URI=https://acme-staging-v02.api.letsencrypt.org/directory
```

### Trovare la Rete Docker Corretta

```bash
# Lista reti disponibili
docker network ls

# Esempi:
# - Se usi n8n: n8n-net
# - Se usi chatwoot: chatwoot_default
# - Se usi docker-compose in una cartella: nomecartella_default
```

## 🔧 Configurazione Servizi

### Modo Interattivo

```bash
sudo ./add-service.sh
```

Wizard che ti guida passo passo per configurare ogni servizio.

### Modo Batch (Più Servizi)

```bash
sudo ./add-service.sh --batch --base example.com
```

Configura automaticamente n8n, chatwoot, portainer, ecc.

### Modalità CLI (Per Script/CI/CD)

```bash
# Setup proxy
sudo ./setup.sh

# Aggiunta servizio
sudo ./add-service.sh -c chatwoot-rails -d chatwoot.example.com -p 3000 -y

# Lista servizi
sudo ./add-service.sh --list
```

## 📊 Architettura di Rete

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet (Port 80/443)                   │
└──────────────────────────┬──────────────────────────────────┘
                           │
                ┌──────────▼─────────────┐
                │   nginx-proxy          │
                │ (Reverse Proxy)        │
                └──┬──────────────────┬──┘
                   │                  │
         ┌─────────▼──┐      ┌────────▼──────────┐
         │proxy-network│      │n8n-net (External)│
         │  (Internal) │      │ or chatwoot_def  │
         └─────────────┘      └────────┬─────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    │                  │                  │
            ┌───────▼────────┐ ┌───────▼────────┐ ┌───────▼────────┐
            │   Chatwoot     │ │      n8n       │ │   Portainer    │
            │  :3000/tcp     │ │   :5678/tcp    │ │   :9443/tcp    │
            └────────────────┘ └────────────────┘ └────────────────┘
```

**Due reti per nginx-proxy:**

1. **proxy-network** (interna): comunicazione tra nginx-proxy e acme-companion
2. **external-services** (n8n-net, chatwoot_default, etc): per raggiungere i backend

Questo design permette a nginx-proxy di **stare su due reti** e fungere da bridge tra internet e i servizi interni.

## 🔒 SSL/TLS

### Produzione (Certificati Validi)

```bash
# Default - certificati Let's Encrypt validi
sudo ./setup.sh
```

Limiti: max 5 certificati per settimana per dominio.

### Staging (Per Testing)

Edita `.env` e aggiungi:

```bash
ACME_CA_URI=https://acme-staging-v02.api.letsencrypt.org/directory
```

Poi riavvia:

```bash
sudo ./setup.sh
```

Certificati illimitati ma NON validi nei browser.

## 📝 Esempi di Utilizzo

### Scenario 1: Chatwoot + n8n + Portainer

```bash
# 1. Setup base
sudo ./setup.sh
# Inserire email e confermare rete n8n-net

# 2. Configurare i servizi
sudo ./add-service.sh --batch --base tasuthor.com

# Output:
# ┌──────────────────────┬──────────────────────────────┬───────┐
# │ Container            │ Sottodominio                 │ Porta │
# ├──────────────────────┼──────────────────────────────┼───────┤
# │ chatwoot-rails       │ chatwoot.tasuthor.com        │  3000 │
# │ n8n                  │ n8n.tasuthor.com             │  5678 │
# │ portainer            │ portainer.tasuthor.com       │  9443 │
# └──────────────────────┴──────────────────────────────┴───────┘
```

### Scenario 2: Solo Chatwoot

```bash
sudo ./setup.sh

# Configurazione manuale
sudo ./add-service.sh
# Selezionare chatwoot-rails
# Inserire: chatwoot.mycompany.com
```

### Scenario 3: Ambiente Produzione con Backup

```bash
# Backup configurazione
tar -czf nginx-proxy-backup-$(date +%s).tar.gz \
  docker-compose.yml .env configs/ vhost-configs/

# Setup
sudo ./setup.sh

# Restore se necessario
tar -xzf nginx-proxy-backup-*.tar.gz
sudo docker compose down && docker compose up -d
```

## 🧪 Verifica

### Controllare lo Stato

```bash
# Container in esecuzione
docker ps | grep nginx

# Rete esterna connessa
docker network inspect n8n-net | grep nginx-proxy

# Certificati SSL
docker exec nginx-proxy ls /etc/nginx/certs/ | grep tasuthor.com
```

### Test API (Chatwoot)

```bash
curl --request GET \
  --url "https://chatwoot.tasuthor.com/api/v1/accounts/1/contacts?page=1" \
  --header "Authorization: Bearer YOUR_TOKEN"

# Risultato atteso: {"payload": [...], "meta": {...}}
```

### Test HTTPS

```bash
curl -I https://chatwoot.tasuthor.com
# HTTP/2 200
# x-frame-options: SAMEORIGIN
```

## 🔍 Diagnostica

### Log nginx-proxy

```bash
# Ultimi 50 log
docker logs nginx-proxy | tail -50

# Real-time monitoring
docker logs -f nginx-proxy
```

### Log acme-companion (certificati)

```bash
docker logs -f nginx-proxy-acme | grep -i "chatwoot.tasuthor.com"
```

### Verifica configurazione nginx

```bash
docker exec nginx-proxy nginx -T | grep -A 10 "server_name chatwoot"
```

### Reset completo

```bash
# Backup .env e configurazioni prima di fare questo!
docker compose down
docker volume rm nginx-certs nginx-vhost nginx-html acme-state
sudo ./setup.sh
```

## 📁 File Struttura

```
nginx-proxy/
├── setup.sh                 # Setup iniziale (NUOVO)
├── install.sh              # Setup avanzato (legacy)
├── add-service.sh          # Configurazione servizi
├── .env.example            # Template configurazione
├── docker-compose.yml      # Config Docker (AGGIORNATO)
├── custom-nginx.conf       # Configurazioni nginx globali
├── lib/
│   ├── common.sh           # Funzioni base
│   ├── docker_ops.sh       # Operazioni Docker
│   ├── ssl_config.sh       # Configurazione SSL
│   ├── vhost_manager.sh    # Gestione vhost (AGGIORNATO)
│   ├── container_setup.sh  # Ricreazione container
│   └── prompts.sh          # UI interattiva
├── configs/                # Configurazioni servizi salvate
├── vhost-configs/          # Configurazioni vhost nginx
└── README.md              # Questo file
```

## 🔄 Workflow Tipico

### Primo Setup

```bash
# 1. Setup proxy
sudo ./setup.sh

# 2. Configurare un servizio
sudo ./add-service.sh -c chatwoot-rails -d chatwoot.example.com -p 3000 -y

# 3. Attendere certificato SSL (1-2 minuti)
docker logs -f nginx-proxy-acme | grep "chatwoot.example.com"

# 4. Test
curl -I https://chatwoot.example.com
```

### Aggiungere Nuovo Servizio

```bash
# Il container deve essere avviato e esporre una porta
docker ps | grep mio-servizio

# Configurare
sudo ./add-service.sh -c mio-servizio -d mio-servizio.example.com -p 8080 -y

# Verificare
docker logs -f nginx-proxy-acme | grep "mio-servizio"
curl -I https://mio-servizio.example.com
```

### Modificare Dominio Servizio

```bash
# Rimuovere vecchia configurazione
rm configs/chatwoot.conf
rm vhost-configs/chatwoot.tasuthor.com

# Rimuovere dal container
docker network disconnect nginx-proxy_proxy-network chatwoot-rails-1 2>/dev/null || true

# Aggiungere nuovo dominio
sudo ./add-service.sh -c chatwoot-rails -d new-chatwoot.example.com -p 3000 -y

# Nginx si ricarica automaticamente
```

## 🎯 Configurazione Avanzata

### Custom Vhost Config

Per servizi speciali (API, WebSocket, etc), vedi `lib/vhost_manager.sh`:

```bash
# Chatwoot (API con Authorization headers):
create_api_config()

# WebSocket (n8n, Socket.io):
create_websocket_config()

# HTTPS backend (Portainer):
create_portainer_https_config()
```

### Health Check

Il docker-compose include healthcheck per nginx-proxy:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost"]
  interval: 30s
  timeout: 10s
  retries: 3
```

Acme-companion dipende da nginx-proxy con `condition: service_healthy`.

## ⚠️ Troubleshooting

### nginx-proxy non si avvia

```bash
# 1. Verificare .env
cat .env

# 2. Verificare rete
docker network inspect ${DOCKER_NETWORK}

# 3. Log dettagliati
docker logs nginx-proxy | head -100

# 4. Reset
docker compose down -v
sudo ./setup.sh
```

### Certificato non emesso

```bash
# 1. Controllare log acme
docker logs nginx-proxy-acme | grep -i "error"

# 2. Verificare DNS
dig +short chatwoot.example.com

# 3. Verificare port forwarding
curl -I http://chatwoot.example.com:80

# 4. Se in staging, switch a produzione:
# Edita .env, rimuovi ACME_CA_URI, riavvia setup.sh
```

### Container backend non raggiungibile

```bash
# 1. Verificare container in esecuzione
docker ps | grep chatwoot

# 2. Verificare rete
docker network inspect n8n-net | grep "chatwoot-rails"

# 3. Test manuale da nginx-proxy
docker exec nginx-proxy curl http://chatwoot-rails-1:3000

# 4. Se fallisce, container non è sulla rete corretta
docker network connect n8n-net chatwoot-rails-1
```

## 📚 Riferimenti

- [nginx-proxy Documentation](https://github.com/nginx-proxy/nginx-proxy)
- [acme-companion Documentation](https://github.com/nginx-proxy/acme-companion)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Docker Networks](https://docs.docker.com/network/)

## 💡 Best Practices

1. **Sempre fare backup** del `.env` e configurazioni prima di modifiche
2. **Usare modalità staging** per testing (evita rate limits)
3. **Monitorare i log** durante prima configurazione
4. **Documentare** sottodomini e porte utilizzate
5. **Aggiornare regolarmente** le immagini Docker
6. **Test HTTPS** subito dopo configurazione

---

**Versione**: 2.0 (Gennaio 2026)
**Autore**: Installation Guide Docker
**Ultimo Update**: 2026-01-06

