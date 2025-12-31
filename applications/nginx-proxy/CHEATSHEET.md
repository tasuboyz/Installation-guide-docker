# Nginx Proxy - Cheatsheet Rapido

## Setup Iniziale

```bash
# Installazione interattiva
sudo ./install.sh

# Installazione automatica (produzione)
sudo ./install.sh --email ops@example.com --yes

# Installazione staging (test)
sudo ./install.sh --email ops@example.com --staging --yes
```

## Configurazione Servizi

```bash
# Interattivo (consigliato)
sudo ./setup-subdomain.sh

# Automatico
sudo ./setup-subdomain.sh -s n8n.example.com -c n8n -p 5678 -y

# Auto-detect porta
sudo ./setup-subdomain.sh -s app.example.com -c myapp -y
```

## Comandi Utili

### Verifica Status
```bash
# Container in esecuzione
docker ps | grep nginx-proxy

# Log proxy
docker logs nginx-proxy --tail 50

# Log certificati SSL
docker logs nginx-proxy-acme --tail 50 -f

# Test configurazione nginx
docker exec nginx-proxy nginx -t
```

### Certificati
```bash
# Lista certificati
docker exec nginx-proxy-acme ls -la /etc/nginx/certs/

# Controlla scadenza
echo | openssl s_client -servername n8n.example.com -connect n8n.example.com:443 2>/dev/null | openssl x509 -noout -dates

# Forza rinnovo manuale
docker exec nginx-proxy-acme /app/force_renew
```

### Test Endpoint
```bash
# Test HTTP
curl -I http://n8n.example.com

# Test HTTPS
curl -I https://n8n.example.com

# Test redirect HTTP->HTTPS
curl -L -I http://n8n.example.com

# Dettaglio SSL
openssl s_client -connect n8n.example.com:443 -servername n8n.example.com < /dev/null
```

### Debug Container
```bash
# Ispeziona configurazione container
docker inspect n8n | grep -E "VIRTUAL_HOST|LETSENCRYPT|Networks"

# Check network
docker network inspect glpi-net

# Test connettività interna
docker exec nginx-proxy curl http://n8n:5678
docker exec nginx-proxy ping n8n
```

### Manutenzione
```bash
# Riavvia proxy
docker compose restart nginx-proxy

# Riavvia acme-companion
docker compose restart acme-companion

# Ricrea container (reset completo)
docker compose down
docker compose up -d

# Pulisci volumi (ATTENZIONE: perde certificati!)
docker compose down -v
```

## Troubleshooting Rapido

### Certificato non emesso
```bash
# 1. Verifica DNS
nslookup n8n.example.com

# 2. Verifica porta 80 aperta
curl -I http://n8n.example.com/.well-known/acme-challenge/test

# 3. Log acme
docker logs nginx-proxy-acme | grep n8n.example.com

# 4. Verifica env container
docker inspect n8n | grep -E "VIRTUAL_HOST|LETSENCRYPT"
```

### 502 Bad Gateway
```bash
# 1. Container target raggiungibile?
docker exec nginx-proxy curl http://n8n:5678

# 2. Container sulla rete corretta?
docker network inspect glpi-net | grep n8n

# 3. Porta esposta corretta?
docker inspect n8n | grep ExposedPorts
```

### 504 Gateway Timeout
```bash
# Aumenta timeout in custom-nginx.conf
echo 'proxy_read_timeout 900s;' >> custom-nginx.conf
docker compose restart nginx-proxy
```

## Workflow Completo Setup

```bash
# 1. Installa proxy
sudo ./install.sh --yes

# 2. Avvia servizio (esempio n8n)
docker run -d --name n8n --network glpi-net n8nio/n8n

# 3. Configura proxy + SSL
sudo ./setup-subdomain.sh -s n8n.example.com -c n8n -y

# 4. Attendi certificato (2-3 min)
docker logs -f nginx-proxy-acme

# 5. Testa
curl -I https://n8n.example.com
```

## Riferimenti Rapidi

- **Porta HTTP**: 80
- **Porta HTTPS**: 443
- **Network default**: glpi-net
- **Certificati path**: `/etc/nginx/certs` (dentro container)
- **Vhost config**: `/etc/nginx/vhost.d` (dentro container)
- **Rate limit prod**: 5 cert/week per dominio
- **Rate limit staging**: illimitato (cert non fidati)

## Variabili Ambiente Servizi

Ogni servizio deve avere:
```yaml
environment:
  - VIRTUAL_HOST=subdomain.example.com
  - VIRTUAL_PORT=5678  # porta interna
  - LETSENCRYPT_HOST=subdomain.example.com
  - LETSENCRYPT_EMAIL=admin@example.com
networks:
  - glpi-net
expose:
  - "5678"
```

Oppure usa `./setup-subdomain.sh` per configurazione automatica!
