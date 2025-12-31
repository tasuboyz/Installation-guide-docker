# Nginx Reverse Proxy + Certbot SSL

Nginx reverse proxy automatico con gestione certificati SSL Let's Encrypt per tutti i servizi dell'ecosistema (n8n, Chatwoot, GLPI).

## Caratteristiche

- **Reverse proxy automatico**: nginx-proxy rileva automaticamente i container e configura i virtual host
- **SSL automatico**: acme-companion richiede e rinnova automaticamente i certificati Let's Encrypt
- **WebSocket support**: Configurato per Chatwoot e n8n
- **Alta capacità**: Timeout e buffer ottimizzati per workflow lunghi e upload di file
- **Logging**: Log rotati automaticamente per evitare consumo eccessivo di spazio
- **Setup automatizzato**: Script CLI per configurazione sottodomini con scan porte e DNS check

## Prerequisiti

- Docker e Docker Compose installati
- Rete Docker `glpi-net` (creata automaticamente dallo script se mancante)
- DNS configurato per puntare ai sottodomini desiderati
- Porte 80 e 443 aperte nel firewall

## Quick Start

### 1. Installazione nginx-proxy

**Modalità interattiva:**
```bash
sudo ./install.sh
```

**Modalità automatica (non-interactive):**
```bash
sudo ./install.sh --subdomain proxy.example.com --email admin@example.com --network glpi-net --yes
```

### 1. Installazione nginx-proxy

**Modalità interattiva:**
```bash
sudo ./install.sh
```
Ti chiederà solo: email e modalità (staging/produzione).

**Modalità automatica:**
```bash
sudo ./install.sh --email admin@example.com --yes
```

**Modalità staging (per test senza rate limit):**
```bash
sudo ./install.sh --email admin@example.com --staging --yes
```

### 2. Configurare un servizio

**Modalità interattiva (consigliata):**
```bash
sudo ./setup-subdomain.sh
```

Lo script:
1. Lista tutti i container attivi
2. Ti fa scegliere il container
3. Rileva automaticamente le porte esposte
4. Ti fa selezionare la porta (o auto-seleziona)
5. Chiede il sottodominio
6. Verifica DNS
7. Configura il container
8. Monitora l'emissione del certificato SSL

**Modalità automatica:**
```bash
sudo ./setup-subdomain.sh --subdomain n8n.example.com --container n8n --port 5678 --yes
```

**Con selezione porta automatica:**
```bash
sudo ./setup-subdomain.sh --subdomain chatwoot.example.com --container chatwoot_rails_1 --yes
```

### Esempio completo: setup n8n

```bash
# 1. Installa proxy (una sola volta)
sudo ./install.sh --email admin@example.com --yes

# 2. Avvia n8n normalmente
docker run -d \
  --name n8n \
  --network glpi-net \
  -v n8n_data:/home/node/.n8n \
  n8nio/n8n

# 3. Configura proxy + SSL
sudo ./setup-subdomain.sh --subdomain n8n.tasuthor.com --container n8n --yes

# 4. Dopo 1-2 minuti: https://n8n.tasuthor.com funziona!
```

## Opzioni CLI

### install.sh
```bash
sudo ./install.sh [--email <email>] [--network <name>] [--staging|--production] [--yes]
```
| Opzione | Descrizione |
|---------|-------------|
| `--email, -e` | Email per Let's Encrypt (obbligatoria) |
| `--network, -n` | Rete Docker (default: glpi-net) |
| `--staging` | Usa certificati test (illimitati) |
| `--production` | Usa certificati reali (default) |
| `--yes, -y` | Non interattivo |

### setup-subdomain.sh
```bash
sudo ./setup-subdomain.sh [--subdomain <host>] [--container <name>] [--port <port>] [--yes]
```
| Opzione | Descrizione |
|---------|-------------|
| `--subdomain, -s` | Sottodominio completo (es: n8n.example.com) |
| `--container, -c` | Nome container Docker |
| `--port, -p` | Porta interna (auto-rilevata se omessa) |
| `--yes, -y` | Non interattivo |

## Configurazione Manuale (alternativa)

Se preferisci configurare manualmente senza script, aggiungi queste variabili d'ambiente al `docker-compose.yml` del servizio:

```yaml
services:
  myservice:
    image: myimage:latest
    environment:
      - VIRTUAL_HOST=myservice.example.com
      - VIRTUAL_PORT=8080  # porta interna del servizio
      - LETSENCRYPT_HOST=myservice.example.com
      - LETSENCRYPT_EMAIL=admin@example.com
    networks:
      - glpi-net
    expose:
      - "8080"

networks:
  glpi-net:
    external: true
```

Poi riavvia il servizio:
```bash
docker compose up -d myservice
```

## Esempi Configurazione

### Chatwoot

```yaml
services:
  rails:
    environment:
      - VIRTUAL_HOST=chatwoot.example.com
      - VIRTUAL_PORT=3000
      - LETSENCRYPT_HOST=chatwoot.example.com
      - LETSENCRYPT_EMAIL=admin@example.com
      - FRONTEND_URL=https://chatwoot.example.com
    networks:
      - glpi-net
    expose:
      - "3000"
```

### n8n

```bash
docker run -d \
  --name n8n \
  --network glpi-net \
  -e VIRTUAL_HOST=n8n.example.com \
  -e VIRTUAL_PORT=5678 \
  -e LETSENCRYPT_HOST=n8n.example.com \
  -e LETSENCRYPT_EMAIL=admin@example.com \
  -e N8N_HOST=n8n.example.com \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=https://n8n.example.com/ \
  --expose 5678 \
  n8nio/n8n
```

## Opzioni Avanzate

### Configurazione Manuale (senza script)

Se preferisci configurare manualmente, aggiungi queste variabili d'ambiente al `docker-compose.yml` del servizio:

```yaml
services:
  myservice:
    image: myimage:latest
    environment:
      - VIRTUAL_HOST=myservice.example.com
      - VIRTUAL_PORT=8080  # porta interna del servizio
      - LETSENCRYPT_HOST=myservice.example.com
      - LETSENCRYPT_EMAIL=admin@example.com
    networks:
      - glpi-net
    expose:
      - "8080"

networks:
  glpi-net:
    external: true
```

Poi riavvia:
```bash
docker compose up -d myservice
```

### Opzioni CLI

**install.sh:**
```bash
sudo ./install.sh [--subdomain <host>] [--email <mail>] [--network <name>] [--staging] [--production] [--yes]
```

**setup-subdomain.sh:**
```bash
sudo ./setup-subdomain.sh [--subdomain <host>] [--container <name>] [--port <port>] [--backend <url>] [--yes]
```

Esempi:
```bash
# Setup automatico n8n con porta auto-rilevata
sudo ./setup-subdomain.sh -s n8n.example.com -c n8n -y

# Setup con backend personalizzato
sudo ./setup-subdomain.sh -s api.example.com -b http://192.168.1.100:8080 -y

# Modalità staging per test
sudo ./install.sh --staging -y
sudo ./setup-subdomain.sh -s test.example.com -c myapp -y
```

### Esempi per servizi comuni

#### Chatwoot
```bash
# Assumendo che chatwoot sia già in esecuzione
sudo ./setup-subdomain.sh --subdomain chatwoot.example.com --container chatwoot_rails_1 --port 3000 --yes
```

#### n8n
```bash
sudo ./setup-subdomain.sh --subdomain n8n.example.com --container n8n --port 5678 --yes
```

#### GLPI
```bash
sudo ./setup-subdomain.sh --subdomain glpi.example.com --container glpi --port 80 --yes
```

## Verifica Certificati

### Controlla stato certificato

```bash
# Lista certificati emessi
docker exec nginx-proxy-acme /app/cert_status

# Verifica certificato specifico
openssl s_client -connect chatwoot.example.com:443 -servername chatwoot.example.com < /dev/null

# Controlla scadenza
echo | openssl s_client -servername chatwoot.example.com -connect chatwoot.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Visualizza log

```bash
# Log nginx-proxy
docker logs nginx-proxy -f

# Log acme-companion (certificati)
docker logs nginx-proxy-acme -f
```

## Troubleshooting

### Il certificato non viene emesso

1. **Verifica DNS**:
   ```bash
   nslookup tuodominio.example.com
   dig tuodominio.example.com
   ```

2. **Verifica raggiungibilità HTTP** (porta 80 deve essere aperta):
   ```bash
   curl -I http://tuodominio.example.com
   ```

3. **Controlla log acme-companion**:
   ```bash
   docker logs nginx-proxy-acme --tail 100
   ```

4. **Verifica configurazione servizio**:
   ```bash
   docker inspect tuocontainer | grep -E "VIRTUAL_HOST|LETSENCRYPT"
   ```

### Rate limit Let's Encrypt

Se hai raggiunto il rate limit (5 certificati/settimana per dominio), usa l'ambiente staging:

```bash
# Aggiungi a .env
ACME_CA_URI=https://acme-staging-v02.api.letsencrypt.org/directory
```

**NOTA**: I certificati staging non sono fidati dai browser, usa solo per test.

### Errore "Connection refused"

1. Verifica che il servizio sia sulla rete corretta:
   ```bash
   docker inspect tuocontainer | grep -A 10 Networks
   ```

2. Verifica che la porta sia esposta:
   ```bash
   docker port tuocontainer
   ```

3. Test connettività interna:
   ```bash
   docker exec nginx-proxy curl http://tuocontainer:porta
   ```

### Timeout su upload grandi

Se ricevi errori 504 o timeout su upload, aumenta i limiti in [custom-nginx.conf](custom-nginx.conf):

```nginx
client_max_body_size 500M;  # aumenta se necessario
proxy_read_timeout 900s;     # 15 minuti
```

Poi riavvia:
```bash
docker compose restart nginx-proxy
```

## Backup e Ripristino

### Backup certificati

```bash
# Backup volume certificati
docker run --rm -v nginx-proxy_nginx-certs:/certs -v $(pwd):/backup alpine tar czf /backup/certs-backup.tar.gz -C /certs .

# Backup configurazioni vhost
docker run --rm -v nginx-proxy_nginx-vhost:/vhost -v $(pwd):/backup alpine tar czf /backup/vhost-backup.tar.gz -C /vhost .
```

### Ripristino

```bash
# Ripristina certificati
docker run --rm -v nginx-proxy_nginx-certs:/certs -v $(pwd):/backup alpine tar xzf /backup/certs-backup.tar.gz -C /certs

# Ripristina vhost
docker run --rm -v nginx-proxy_nginx-vhost:/vhost -v $(pwd):/backup alpine tar xzf /backup/vhost-backup.tar.gz -C /vhost

# Riavvia proxy
docker compose restart
```

## Sicurezza

### Best Practices

1. **Firewall**: Blocca porte dirette dei servizi (3000, 5678, etc.), lascia solo 80 e 443
   ```bash
   # Esempio UFW
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw deny 3000/tcp  # Chatwoot
   sudo ufw deny 5678/tcp  # n8n
   ```

2. **Aggiorna regolarmente le immagini**:
   ```bash
   docker compose pull
   docker compose up -d
   ```

3. **Monitora i log per accessi sospetti**:
   ```bash
   docker logs nginx-proxy | grep -E "40[0-9]|50[0-9]"
   ```

4. **Rinnovo automatico certificati**: acme-companion rinnova automaticamente 30 giorni prima della scadenza

## Workflow Completo: Setup Produzione

Esempio completo per setup multi-servizio in produzione:

```bash
# 1. Installa nginx-proxy (produzione)
cd /opt/nginx-proxy
sudo ./install.sh --email ops@example.com --network app-net --production --yes

# 2. Avvia servizi (esempio: n8n e Chatwoot)
# n8n
docker run -d \
  --name n8n \
  --network app-net \
  -v n8n_data:/home/node/.n8n \
  n8nio/n8n

# Chatwoot (docker-compose)
cd /opt/chatwoot
docker compose up -d

# 3. Configura proxy + SSL per ogni servizio
cd /opt/nginx-proxy

# n8n
sudo ./setup-subdomain.sh \
  --subdomain n8n.example.com \
  --container n8n \
  --port 5678 \
  --yes

# Chatwoot (auto-detect port)
sudo ./setup-subdomain.sh \
  --subdomain chat.example.com \
  --container chatwoot_rails_1 \
  --yes

# 4. Verifica certificati (dopo 2-3 minuti)
curl -I https://n8n.example.com
curl -I https://chat.example.com

# 5. Check logs se necessario
docker logs -f nginx-proxy-acme
```

### Test Staging Locale

Per testare il workflow senza consumare rate limit Let's Encrypt:

```bash
# 1. Setup staging
sudo ./install.sh --staging --yes

# 2. Setup servizio test
docker run -d --name nginx-test --network glpi-net nginx:alpine

sudo ./setup-subdomain.sh \
  --subdomain test.local.example.com \
  --container nginx-test \
  --port 80 \
  --yes

# 3. Verifica (certificato sarà "Fake LE Intermediate X1")
curl -Ik https://test.local.example.com

# 4. Cleanup e switch a produzione
sudo ./install.sh --production --yes
```

## Supporto

Per problemi o domande:
- Controlla [Troubleshooting](#troubleshooting)
- Logs: `docker logs nginx-proxy` e `docker logs nginx-proxy-acme`
- Issue tracker del progetto nginx-proxy: [github.com/nginx-proxy/nginx-proxy](https://github.com/nginx-proxy/nginx-proxy)
- Issue tracker acme-companion: [github.com/nginx-proxy/acme-companion](https://github.com/nginx-proxy/acme-companion)
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

2. **Rate limiting**: Aggiungi rate limiting per API:
   ```nginx
   # In custom-nginx.conf
   limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
   ```

3. **Headers sicurezza**: Già configurati in custom-nginx.conf

4. **Monitoring**: Configura alerting per scadenza certificati

## Manutenzione

### Aggiornamento immagini

```bash
docker compose pull
docker compose up -d
```

### Pulizia certificati scaduti

```bash
docker exec nginx-proxy-acme /app/cleanup_certificates
```

### Monitoraggio spazio disco

I log sono già configurati con rotazione (max 10MB x 3 file per container).

Per vedere lo spazio usato dai volumi:
```bash
docker system df -v
```

## Supporto Multi-dominio

Puoi configurare più domini per lo stesso servizio:

```yaml
environment:
  - VIRTUAL_HOST=app.example.com,app.example.org
  - LETSENCRYPT_HOST=app.example.com,app.example.org
```

Verranno emessi certificati separati per ciascun dominio.

## Risorse

- [nginx-proxy Documentation](https://github.com/nginx-proxy/nginx-proxy)
- [acme-companion Documentation](https://github.com/nginx-proxy/acme-companion)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
