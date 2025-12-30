# 05 - Nginx Reverse Proxy e Gestione SSL

## Panoramica

Configurazione di un reverse proxy nginx centralizzato con gestione automatica dei certificati SSL tramite Let's Encrypt per tutti i servizi dell'ecosistema.

### Architettura

```
Internet (porta 80/443)
          ↓
    [nginx-proxy]
          ↓
    ┌─────┴─────┬──────────┬─────────┐
    ↓           ↓          ↓         ↓
  Chatwoot     n8n       GLPI    Altri
  (porta 3000) (5678)    (80)    servizi
```

**Componenti:**
- **nginxproxy/nginx-proxy**: Reverse proxy automatico che configura virtual host basandosi sui container Docker
- **nginxproxy/acme-companion**: Gestione automatica certificati SSL Let's Encrypt (richiesta, rinnovo, installazione)
- **Rete glpi-net**: Rete Docker condivisa che connette tutti i servizi

## Vantaggi

✅ **SSL automatico**: Certificati richiesti e rinnovati automaticamente  
✅ **Configurazione zero**: I servizi si registrano automaticamente tramite variabili d'ambiente  
✅ **WebSocket support**: Configurato per Chatwoot e n8n  
✅ **Alta performance**: Buffer e timeout ottimizzati  
✅ **Sicurezza**: Headers di sicurezza preconfigurati  
✅ **Manutenzione**: Log rotati automaticamente

## Prerequisiti

1. Docker e Docker Compose installati
2. Rete Docker `glpi-net` esistente
3. **DNS configurato**: I record A/AAAA devono puntare all'IP del server
4. Porte 80 e 443 aperte nel firewall

### Verifica DNS

Prima dell'installazione, verifica che i tuoi domini puntino al server:

```bash
# Linux/Mac
nslookup chatwoot.tuodominio.com
dig chatwoot.tuodominio.com

# Windows
nslookup chatwoot.tuodominio.com
```

L'IP restituito deve corrispondere all'IP pubblico del server.

## Installazione

### 1. Preparazione

```bash
cd applications/nginx-proxy
```

### 2. Configurazione Email

Copia e modifica il file `.env`:

```bash
cp .env.example .env
nano .env
```

Imposta la tua email per le notifiche Let's Encrypt:

```env
LETSENCRYPT_EMAIL=admin@tuodominio.com
```

### 3. Installazione Automatica

Esegui lo script di installazione:

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

Lo script:
- Verifica prerequisiti (Docker, Docker Compose)
- Crea la rete `glpi-net` se non esiste
- Valida l'email configurata
- Avvia nginx-proxy e acme-companion
- Verifica che i container siano in esecuzione

### 4. Verifica Installazione

```bash
# Controlla che i container siano attivi
docker ps | grep nginx-proxy

# Dovresti vedere:
# nginx-proxy
# nginx-proxy-acme

# Verifica i log
docker logs nginx-proxy
docker logs nginx-proxy-acme
```

## Configurazione Servizi

### Metodo Automatico: setup-subdomain.sh

Lo script interattivo semplifica la configurazione:

```bash
sudo ./setup-subdomain.sh
```

**Procedura:**
1. Mostra i container attivi
2. Richiede il nome del container da configurare
3. Richiede il sottodominio desiderato
4. Verifica la risoluzione DNS
5. Auto-rileva la porta interna o permette configurazione manuale
6. Genera file di configurazione docker-compose

### Metodo Manuale

#### Chatwoot

Modifica `applications/chatwoot/docker-compose.yaml`:

```yaml
services:
  rails:
    environment:
      # Proxy configuration
      - VIRTUAL_HOST=chatwoot.tuodominio.com
      - VIRTUAL_PORT=3000
      - LETSENCRYPT_HOST=chatwoot.tuodominio.com
      - LETSENCRYPT_EMAIL=admin@tuodominio.com
      
      # Chatwoot specific
      - FRONTEND_URL=https://chatwoot.tuodominio.com
    
    # Rimuovi o commenta 'ports', usa 'expose'
    # ports:
    #   - '3000:3000'
    expose:
      - "3000"
    
    networks:
      - default
      - glpi-net

networks:
  glpi-net:
    external: true
```

Riavvia Chatwoot:

```bash
cd applications/chatwoot
docker compose down
docker compose up -d
```

#### n8n

Aggiorna `core-ecosystem/04-n8n-installation.md` con i nuovi comandi o usa docker-compose.

**Esempio con docker run:**

```bash
docker run -d \
  --name n8n \
  --network glpi-net \
  -e VIRTUAL_HOST=n8n.tuodominio.com \
  -e VIRTUAL_PORT=5678 \
  -e LETSENCRYPT_HOST=n8n.tuodominio.com \
  -e LETSENCRYPT_EMAIL=admin@tuodominio.com \
  -e N8N_HOST=n8n.tuodominio.com \
  -e N8N_PROTOCOL=https \
  -e N8N_PORT=5678 \
  -e WEBHOOK_URL=https://n8n.tuodominio.com/ \
  -v n8n_data:/home/node/.n8n \
  --expose 5678 \
  n8nio/n8n
```

**Esempio con docker-compose:**

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    environment:
      - VIRTUAL_HOST=n8n.tuodominio.com
      - VIRTUAL_PORT=5678
      - LETSENCRYPT_HOST=n8n.tuodominio.com
      - LETSENCRYPT_EMAIL=admin@tuodominio.com
      - N8N_HOST=n8n.tuodominio.com
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n.tuodominio.com/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=n8n-db
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
    networks:
      - glpi-net
    expose:
      - "5678"
    volumes:
      - n8n_data:/home/node/.n8n
    restart: unless-stopped
    depends_on:
      - n8n-db

  n8n-db:
    image: postgres:15
    container_name: n8n-db
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    networks:
      - glpi-net
    volumes:
      - n8n_db_data:/var/lib/postgresql/data
    restart: unless-stopped

networks:
  glpi-net:
    external: true

volumes:
  n8n_data:
  n8n_db_data:
```

#### GLPI

Se GLPI usa docker-compose, aggiungi:

```yaml
services:
  glpi:
    environment:
      - VIRTUAL_HOST=glpi.tuodominio.com
      - VIRTUAL_PORT=80
      - LETSENCRYPT_HOST=glpi.tuodominio.com
      - LETSENCRYPT_EMAIL=admin@tuodominio.com
    networks:
      - glpi-net
    expose:
      - "80"

networks:
  glpi-net:
    external: true
```

## Verifica Certificati SSL

### Stato Certificati

```bash
# Verifica certificati emessi
docker exec nginx-proxy-acme ls -la /etc/nginx/certs/

# Info certificato specifico
openssl x509 -in /var/lib/docker/volumes/nginx-proxy_nginx-certs/_data/chatwoot.tuodominio.com.crt -noout -text

# Verifica scadenza
echo | openssl s_client -servername chatwoot.tuodominio.com -connect chatwoot.tuodominio.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Test Connessione SSL

```bash
# Test HTTPS
curl -I https://chatwoot.tuodominio.com

# Test completo SSL
openssl s_client -connect chatwoot.tuodominio.com:443 -servername chatwoot.tuodominio.com

# Test con dettagli certificato
curl -vI https://chatwoot.tuodominio.com 2>&1 | grep -A 10 "SSL certificate"
```

### Test Online

- [SSL Labs Test](https://www.ssllabs.com/ssltest/)
- [DigiCert Certificate Checker](https://www.digicert.com/help/)

## Troubleshooting

### Certificato Non Emesso

**Problema**: Il certificato SSL non viene generato dopo 5-10 minuti.

**Soluzioni:**

1. **Verifica DNS**:
   ```bash
   nslookup tuodominio.com
   # L'IP deve corrispondere al server
   ```

2. **Verifica porta 80 aperta**:
   ```bash
   curl -I http://tuodominio.com
   # Deve rispondere (anche 404 va bene)
   ```

3. **Controlla log acme-companion**:
   ```bash
   docker logs nginx-proxy-acme --tail 100 -f
   ```

4. **Verifica variabili d'ambiente del servizio**:
   ```bash
   docker inspect tuocontainer | grep -E "VIRTUAL_HOST|LETSENCRYPT"
   ```

5. **Test manuale Let's Encrypt**:
   ```bash
   docker exec nginx-proxy-acme /app/force_renew
   ```

### Rate Limit Let's Encrypt

**Problema**: Errore "too many certificates already issued".

**Soluzione**: Usa l'ambiente staging per test:

1. Modifica `applications/nginx-proxy/.env`:
   ```env
   ACME_CA_URI=https://acme-staging-v02.api.letsencrypt.org/directory
   ```

2. Riavvia:
   ```bash
   docker compose down
   docker compose up -d
   ```

3. I certificati staging **non sono fidati** dai browser, usa solo per debugging.

### Errore 502 Bad Gateway

**Problema**: Nginx restituisce 502 quando accedi al servizio.

**Soluzioni:**

1. **Verifica servizio attivo**:
   ```bash
   docker ps | grep tuoservizio
   ```

2. **Verifica rete corretta**:
   ```bash
   docker inspect tuoservizio | grep -A 10 Networks
   # Deve includere 'glpi-net'
   ```

3. **Verifica porta esposta**:
   ```bash
   docker inspect tuoservizio | grep ExposedPorts
   ```

4. **Test connettività interna**:
   ```bash
   docker exec nginx-proxy curl http://tuoservizio:porta
   ```

5. **Controlla log nginx**:
   ```bash
   docker logs nginx-proxy --tail 50
   ```

### Timeout su Upload Grandi

**Problema**: Errori 504 o timeout su file upload > 10MB.

**Soluzione**: Già configurato fino a 100MB in `custom-nginx.conf`. Per aumentare:

```nginx
# Modifica custom-nginx.conf
client_max_body_size 500M;
proxy_read_timeout 900s;
```

Riavvia:
```bash
docker compose restart nginx-proxy
```

### WebSocket Non Funziona

**Problema**: Chat real-time o webhook n8n non funzionano.

**Verifica**: WebSocket è già abilitato in `custom-nginx.conf`:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

Se ancora non funziona, aggiungi configurazione specifica per il dominio:

```bash
# Crea file su host
sudo mkdir -p /var/lib/docker/volumes/nginx-proxy_nginx-vhost/_data
sudo nano /var/lib/docker/volumes/nginx-proxy_nginx-vhost/_data/chatwoot.tuodominio.com_location

# Aggiungi:
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 86400;
```

## Sicurezza

### Firewall Configuration

Blocca accesso diretto ai servizi, esponi solo nginx:

```bash
# Ubuntu/Debian con UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 3000/tcp  # Chatwoot
sudo ufw deny 5678/tcp  # n8n
sudo ufw enable
```

### Headers di Sicurezza

Già configurati in `custom-nginx.conf`:

- `X-Frame-Options`: Previene clickjacking
- `X-Content-Type-Options`: Previene MIME sniffing
- `X-XSS-Protection`: Protezione XSS

### Basic Authentication

Per proteggere servizi sensibili:

```bash
# Installa htpasswd
sudo apt install apache2-utils

# Crea password per admin.tuodominio.com
sudo htpasswd -c /var/lib/docker/volumes/nginx-proxy_nginx-vhost/_data/htpasswd/admin.tuodominio.com admin

# Il servizio richiederà username/password
```

## Manutenzione

### Aggiornamento

```bash
cd applications/nginx-proxy
docker compose pull
docker compose up -d
```

### Backup Certificati

```bash
# Backup
docker run --rm \
  -v nginx-proxy_nginx-certs:/certs \
  -v $(pwd):/backup \
  alpine tar czf /backup/certs-backup-$(date +%Y%m%d).tar.gz -C /certs .

# Restore
docker run --rm \
  -v nginx-proxy_nginx-certs:/certs \
  -v $(pwd):/backup \
  alpine tar xzf /backup/certs-backup-YYYYMMDD.tar.gz -C /certs
```

### Monitoring

```bash
# Controlla scadenza certificati (alerta se < 30 giorni)
for cert in /var/lib/docker/volumes/nginx-proxy_nginx-certs/_data/*.crt; do
  echo "=== $(basename $cert) ==="
  openssl x509 -in "$cert" -noout -dates
done
```

### Log Analysis

```bash
# Errori recenti nginx
docker logs nginx-proxy --since 1h 2>&1 | grep -i error

# Richieste SSL recenti
docker logs nginx-proxy-acme --since 1h

# Statistiche richieste
docker exec nginx-proxy cat /var/log/nginx/access.log | awk '{print $7}' | sort | uniq -c | sort -rn | head -20
```

## Integrazione con Monitoring

### Prometheus Exporter

Aggiungi nginx-prometheus-exporter per metriche:

```yaml
services:
  nginx-exporter:
    image: nginx/nginx-prometheus-exporter:latest
    command:
      - '-nginx.scrape-uri=http://nginx-proxy/stub_status'
    networks:
      - glpi-net
    ports:
      - "9113:9113"
```

### Grafana Dashboard

Importa dashboard ID 12708 per visualizzare:
- Richieste/sec
- Codici di risposta
- Latenza
- Traffico

## Riferimenti

- [nginx-proxy GitHub](https://github.com/nginx-proxy/nginx-proxy)
- [acme-companion GitHub](https://github.com/nginx-proxy/acme-companion)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Rate Limits Let's Encrypt](https://letsencrypt.org/docs/rate-limits/)

## Prossimi Passi

Dopo aver configurato il reverse proxy:

1. ✅ Configura Chatwoot con SSL
2. ✅ Configura n8n con SSL
3. ✅ Configura GLPI con SSL
4. 📝 [Integrazione n8n ↔ Chatwoot](../workflows/README.md)
5. 📝 Test workflow automatizzati
