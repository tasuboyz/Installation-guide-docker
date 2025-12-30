# Nginx Reverse Proxy + Certbot SSL

Nginx reverse proxy automatico con gestione certificati SSL Let's Encrypt per tutti i servizi dell'ecosistema (n8n, Chatwoot, GLPI).

## Caratteristiche

- **Reverse proxy automatico**: nginx-proxy rileva automaticamente i container e configura i virtual host
- **SSL automatico**: acme-companion richiede e rinnova automaticamente i certificati Let's Encrypt
- **WebSocket support**: Configurato per Chatwoot e n8n
- **Alta capacità**: Timeout e buffer ottimizzati per workflow lunghi e upload di file
- **Logging**: Log rotati automaticamente per evitare consumo eccessivo di spazio

## Prerequisiti

- Docker e Docker Compose installati
- Rete Docker `glpi-net` esistente (creata automaticamente se mancante)
- DNS configurato per puntare ai sottodomini desiderati
- Porte 80 e 443 aperte nel firewall

## Installazione

1. **Copia il file di configurazione**:
   ```bash
   cp .env.example .env
   nano .env
   ```

2. **Configura l'email per Let's Encrypt**:
   ```bash
   LETSENCRYPT_EMAIL=admin@tuodominio.com
   ```

3. **Avvia nginx-proxy**:
   ```bash
   sudo ./install.sh
   ```

## Configurazione Servizi

### Metodo 1: Script Automatico

Usa lo script di configurazione per aggiungere facilmente un servizio:

```bash
sudo ./setup-subdomain.sh
```

Lo script ti guiderà attraverso:
- Selezione del container
- Configurazione del sottodominio
- Verifica DNS
- Generazione configurazione docker-compose

### Metodo 2: Configurazione Manuale

Aggiungi queste variabili d'ambiente al tuo servizio nel `docker-compose.yml`:

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

### GLPI

```yaml
services:
  glpi:
    environment:
      - VIRTUAL_HOST=glpi.example.com
      - VIRTUAL_PORT=80
      - LETSENCRYPT_HOST=glpi.example.com
      - LETSENCRYPT_EMAIL=admin@example.com
    networks:
      - glpi-net
    expose:
      - "80"
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
