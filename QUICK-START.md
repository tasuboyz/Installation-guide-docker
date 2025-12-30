# Guida Rapida: Deployment Completo n8n + Chatwoot + Nginx SSL

Questa guida ti permette di installare l'intero ecosistema con SSL in pochi passaggi.

## 📋 Prerequisiti

- [ ] Server Linux (Ubuntu 20.04+ / Debian 11+)
- [ ] Docker e Docker Compose installati
- [ ] Domini configurati nel DNS:
  - `n8n.tuodominio.com` → IP server
  - `chatwoot.tuodominio.com` → IP server
  - (opzionale) `glpi.tuodominio.com` → IP server
- [ ] Porte 80 e 443 aperte nel firewall
- [ ] Email valida per Let's Encrypt

## 🚀 Installazione Step-by-Step

### Step 1: Crea Rete Docker Condivisa

```bash
docker network create glpi-net
```

### Step 2: Installa Nginx Reverse Proxy + SSL

```bash
cd applications/nginx-proxy
cp .env.example .env
nano .env  # Configura LETSENCRYPT_EMAIL

sudo chmod +x install.sh
sudo ./install.sh
```

**Verifica:**
```bash
docker ps | grep nginx-proxy
# Dovresti vedere: nginx-proxy e nginx-proxy-acme
```

### Step 3: Installa Database PostgreSQL per n8n

```bash
docker run -d \
  --name n8n-postgres \
  --network glpi-net \
  -e POSTGRES_USER=n8n \
  -e POSTGRES_PASSWORD=$(openssl rand -hex 16) \
  -e POSTGRES_DB=n8ndb \
  -v n8n-postgres-data:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:15
```

**Salva la password generata!**

### Step 4: Installa n8n con SSL

```bash
# Sostituisci POSTGRES_PASSWORD con quella generata
# Sostituisci n8n.tuodominio.com con il tuo dominio

docker run -d \
  --name n8n \
  --network glpi-net \
  --expose 5678 \
  -e VIRTUAL_HOST=n8n.tuodominio.com \
  -e VIRTUAL_PORT=5678 \
  -e LETSENCRYPT_HOST=n8n.tuodominio.com \
  -e LETSENCRYPT_EMAIL=admin@tuodominio.com \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=n8n-postgres \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=n8ndb \
  -e DB_POSTGRESDB_USER=n8n \
  -e DB_POSTGRESDB_PASSWORD=PASSWORD_QUI \
  -e N8N_HOST=n8n.tuodominio.com \
  -e N8N_PROTOCOL=https \
  -e N8N_PORT=5678 \
  -e WEBHOOK_URL=https://n8n.tuodominio.com/ \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=$(openssl rand -hex 12) \
  -v n8n-data:/home/node/.n8n \
  --restart unless-stopped \
  n8nio/n8n:latest
```

**Verifica:**
```bash
# Attendi 1-2 minuti per certificato SSL
curl -I https://n8n.tuodominio.com
# Dovrebbe rispondere con 200 o 401
```

**Accedi:** `https://n8n.tuodominio.com` (user: admin, password: quella generata)

### Step 5: Installa Chatwoot

```bash
cd applications/chatwoot

# Copia e configura environment
cp .env.example .env
nano .env
```

**Modifica `.env`:**
```env
# Sostituisci con i tuoi valori
SECRET_KEY_BASE=$(openssl rand -hex 64)
POSTGRES_PASSWORD=$(openssl rand -hex 16)
REDIS_PASSWORD=$(openssl rand -hex 16)
FRONTEND_URL=https://chatwoot.tuodominio.com
```

**Modifica `docker-compose.yaml`:**

Decommentare le righe per proxy SSL:

```yaml
services:
  rails:
    # Commenta ports:
    # ports:
    #   - '3000:3000'
    
    # Decommenta expose e environment:
    expose:
      - "3000"
    environment:
      # ... altre env ...
      - VIRTUAL_HOST=chatwoot.tuodominio.com
      - VIRTUAL_PORT=3000
      - LETSENCRYPT_HOST=chatwoot.tuodominio.com
      - LETSENCRYPT_EMAIL=admin@tuodominio.com
    
    networks:
      - default
      - glpi-net  # decommenta

networks:
  glpi-net:      # decommenta
    external: true  # decommenta
```

**Avvia Chatwoot:**

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

**Verifica:**
```bash
curl -I https://chatwoot.tuodominio.com
docker logs chatwoot-rails -f
```

**Accedi:** `https://chatwoot.tuodominio.com` → Crea primo account admin

### Step 6: Configura Integrazione n8n ↔ Chatwoot

#### 6.1 Ottieni Token API Chatwoot

1. Accedi a Chatwoot
2. Vai su **Profile Settings** → **Access Token**
3. Copia il token

#### 6.2 Trova Account ID e Inbox ID

```bash
# Sostituisci TUO_TOKEN
curl -H "api_access_token: TUO_TOKEN" \
  https://chatwoot.tuodominio.com/api/v1/accounts

# Nota Account ID, poi:
curl -H "api_access_token: TUO_TOKEN" \
  https://chatwoot.tuodominio.com/api/v1/accounts/ACCOUNT_ID/inboxes

# Nota Inbox ID
```

#### 6.3 Configura Credenziali in n8n

1. Accedi a n8n
2. **Credentials** → **New** → "HTTP Header Auth"
3. Configura:
   - Name: `Chatwoot API`
   - Header Name: `api_access_token`
   - Header Value: `<il_tuo_token>`
4. **Credentials** → **New** → "Postgres"
5. Configura:
   - Name: `n8n-postgres`
   - Host: `n8n-postgres`
   - Database: `n8ndb`
   - User: `n8n`
   - Password: `<password_postgres_step3>`

#### 6.4 Importa Workflow

1. In n8n: **Workflows** → **Import from File**
2. Importa `workflows/chatwoot-message-handler.json`
3. Apri il workflow
4. Nei nodi HTTP Request, sostituisci `tuodominio.com`
5. Aggiorna `account_id` nei nodi
6. **Save** e **Active = ON**

#### 6.5 Crea Tabelle Database

```bash
# Connettiti al database
docker exec -it n8n-postgres psql -U n8n -d n8ndb

# Copia e incolla:
CREATE TABLE chatwoot_conversations (
  conversation_id BIGINT PRIMARY KEY,
  account_id INT,
  inbox_id INT,
  contact_id BIGINT,
  contact_name VARCHAR(255),
  contact_email VARCHAR(255),
  status VARCHAR(50),
  assigned_agent VARCHAR(255),
  last_message_at TIMESTAMP,
  last_followup_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE chatwoot_messages (
  id SERIAL PRIMARY KEY,
  conversation_id BIGINT REFERENCES chatwoot_conversations(conversation_id),
  contact_name VARCHAR(255),
  contact_email VARCHAR(255),
  message_content TEXT,
  message_type VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_conversations_status ON chatwoot_conversations(status);
CREATE INDEX idx_conversations_last_message ON chatwoot_conversations(last_message_at);
CREATE INDEX idx_messages_conversation ON chatwoot_messages(conversation_id);

\q
```

#### 6.6 Configura Webhook in Chatwoot

1. In Chatwoot: **Settings** → **Integrations** → **Webhooks**
2. **Add Webhook**
3. Configura:
   - Endpoint URL: `https://n8n.tuodominio.com/webhook/chatwoot-webhook`
   - Events: ☑️ message_created, conversation_created, conversation_status_changed
4. **Save**

#### 6.7 Test Integrazione

1. In Chatwoot, invia un messaggio di test (dalla inbox widget)
2. In n8n, vai su **Executions** → dovresti vedere esecuzione
3. Verifica database:
   ```bash
   docker exec -it n8n-postgres psql -U n8n -d n8ndb -c "SELECT * FROM chatwoot_messages LIMIT 5;"
   ```

## ✅ Verifica Finale

### Test SSL

```bash
# n8n
curl -I https://n8n.tuodominio.com
openssl s_client -connect n8n.tuodominio.com:443 -servername n8n.tuodominio.com < /dev/null

# Chatwoot
curl -I https://chatwoot.tuodominio.com
openssl s_client -connect chatwoot.tuodominio.com:443 -servername chatwoot.tuodominio.com < /dev/null
```

### Test Connettività Interna

```bash
# Da n8n a Chatwoot
docker exec n8n curl -I http://chatwoot-rails:3000

# Da Chatwoot a n8n
docker exec chatwoot-rails curl -I http://n8n:5678
```

### Visualizza Certificati

```bash
docker exec nginx-proxy-acme ls -la /etc/nginx/certs/ | grep -E "n8n|chatwoot"
```

### Container Attivi

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Dovresti vedere:
- ✅ nginx-proxy (Up)
- ✅ nginx-proxy-acme (Up)
- ✅ n8n (Up)
- ✅ n8n-postgres (Up)
- ✅ chatwoot-rails (Up)
- ✅ chatwoot-sidekiq (Up)
- ✅ chatwoot-postgres (Up)
- ✅ chatwoot-redis (Up)

## 🔧 Comandi Utili

### Riavvio Servizi

```bash
# Nginx proxy
cd applications/nginx-proxy
docker compose restart

# n8n
docker restart n8n n8n-postgres

# Chatwoot
cd applications/chatwoot
docker compose restart
```

### Log Real-time

```bash
# n8n
docker logs n8n -f

# Chatwoot
docker logs chatwoot-rails -f

# Nginx
docker logs nginx-proxy -f
docker logs nginx-proxy-acme -f
```

### Backup

```bash
# Backup n8n
docker exec n8n-postgres pg_dump -U n8n n8ndb > n8n-backup-$(date +%Y%m%d).sql

# Backup Chatwoot
docker exec chatwoot-postgres pg_dump -U postgres chatwoot > chatwoot-backup-$(date +%Y%m%d).sql

# Backup certificati SSL
docker run --rm -v nginx-proxy_nginx-certs:/certs -v $(pwd):/backup alpine tar czf /backup/ssl-certs-backup-$(date +%Y%m%d).tar.gz -C /certs .
```

## 🆘 Troubleshooting Rapido

### Certificato SSL non emesso

```bash
# 1. Verifica DNS
nslookup n8n.tuodominio.com
nslookup chatwoot.tuodominio.com

# 2. Controlla log acme
docker logs nginx-proxy-acme --tail 50

# 3. Verifica variabili container
docker inspect n8n | grep -E "VIRTUAL_HOST|LETSENCRYPT"

# 4. Test manuale
docker exec nginx-proxy-acme /app/force_renew
```

### Webhook non funziona

```bash
# 1. Test manuale webhook
curl -X POST https://n8n.tuodominio.com/webhook/chatwoot-webhook \
  -H "Content-Type: application/json" \
  -d '{"event":"test"}'

# 2. Verifica workflow attivo in n8n

# 3. Controlla log
docker logs n8n -f
```

### Database connection error

```bash
# Test connessione PostgreSQL n8n
docker exec -it n8n-postgres psql -U n8n -d n8ndb -c "\conninfo"

# Test connessione PostgreSQL Chatwoot
docker exec -it chatwoot-postgres psql -U postgres -d chatwoot -c "\conninfo"
```

## 📚 Documentazione Completa

- [Nginx Proxy + SSL](core-ecosystem/05-nginx-certbot-ssl.md)
- [n8n Installation](core-ecosystem/04-n8n-installation.md)
- [Chatwoot Installation](applications/chatwoot/README.md)
- [Workflow n8n ↔ Chatwoot](workflows/README.md)

## 🎯 Prossimi Passi

1. **Configura Email** in Chatwoot per notifiche ([guida](https://www.chatwoot.com/docs/self-hosted/deployment/docker#configure-email))
2. **Aggiungi Canali** in Chatwoot (WhatsApp, Telegram, Facebook)
3. **Crea Workflow Avanzati** in n8n per automazioni
4. **Integra GLPI** per ticket automatici
5. **Configura Backup Automatici** (cron jobs)
6. **Monitoring** con Grafana + Prometheus

## 💡 Tips

- **Cambia le password di default** immediatamente
- **Configura firewall** per bloccare porte dirette (3000, 5678)
- **Backup regolari** (almeno settimanale)
- **Monitoring certificati** SSL per scadenza
- **Aggiorna immagini Docker** mensilmente: `docker compose pull && docker compose up -d`
