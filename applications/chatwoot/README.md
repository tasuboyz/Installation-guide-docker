# Chatwoot Installation Setup

Questo repository fornisce un setup unificato per installare Chatwoot, una piattaforma self-hosted per il supporto clienti, utilizzando Docker con Redis e PostgreSQL come container.

## Struttura del Setup

- `install.sh`: Script di installazione automatizzata
- `.env`: File di configurazione ambiente (personalizza con i tuoi valori)
- `.env.example`: Template completo delle variabili ambiente
- `docker-compose.yaml`: Configurazione Docker Compose per tutti i servizi
- `.github/copilot-instructions.md`: Guida per agenti AI

## Servizi Containerizzati

Il setup include tutti i servizi come container Docker:

- **Rails App**: Applicazione principale Chatwoot
- **Sidekiq**: Worker per processi in background
- **PostgreSQL**: Database (con pgvector per funzionalità AI)
- **Redis**: Cache e message broker

## Installazione Rapida

1. **Trasferisci i file** su un server Linux con Docker installato
2. **Personalizza `.env`**:
   - Imposta `FRONTEND_URL` con il tuo dominio
   - Genera una `SECRET_KEY_BASE` sicura (usa `openssl rand -hex 64`)
   - Configura email SMTP se necessario
   - Imposta password sicure per Redis e PostgreSQL
3. **Rendi eseguibile lo script**: `chmod +x install.sh`
4. **Esegui l'installazione**: `sudo ./install.sh`

## Accesso in LAN

Questa configurazione può esporre Chatwoot sulla rete locale (LAN). Per abilitare l'accesso in LAN:

- Nel file `docker-compose.yaml` i servizi ora sono mappati su tutte le interfacce host (es. `3000:3000`).
- Nel file ` .env` imposta `FRONTEND_URL` sull'indirizzo IP del server nella LAN, ad esempio:

```text
FRONTEND_URL=http://192.168.1.42:3000
```

- Avvia i servizi:

```bash
docker compose up -d
```

- Accedi da un altro host nella stessa LAN visitando `http://192.168.1.42:3000`.

Avvertenze di sicurezza:

- Esponendo i servizi sulla LAN, assicurati di limitare l'accesso tramite firewall o regole di rete.
- Non esporre Postgres/Redis in una rete non affidabile senza ulteriori protezioni (VPN, firewall, autenticazione).
- Per un accesso pubblico, usa Nginx come reverse proxy e abilita HTTPS con Let's Encrypt.

## Configurazione Dettagliata

### Dominio e SSL
- Imposta `FRONTEND_URL=https://tuodominio.com`
- Dopo l'installazione, configura Nginx come reverse proxy
- Aggiungi SSL con Let's Encrypt

### Database e Cache
- PostgreSQL e Redis sono già configurati come container
- Le password sono generate automaticamente dallo script
- I dati persistono nei volumi Docker

### Email
- Per produzione, configura SMTP (SendGrid, SES, etc.)
- Oppure usa Postfix sul server

### Storage
- Default: storage locale (non raccomandato per produzione)
- Produzione: configura S3, Azure Blob, o GCS

## Comandi Utili

```bash
# Avvia i servizi
docker compose up -d

# Ferma i servizi
docker compose down

# Aggiorna Chatwoot
docker compose pull
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
docker compose up -d

# Accesso Rails console
docker exec -it $(basename $(pwd))-rails-1 sh -c 'RAILS_ENV=production bundle exec rails c'

# Logs
docker compose logs -f rails
```

## Sicurezza

- Cambia tutte le password di default
- Usa HTTPS in produzione
- Configura firewall per limitare accessi
- Monitora logs regolarmente

## Troubleshooting

- Verifica che Docker sia installato: `docker --version`
- Controlla status servizi: `docker compose ps`
- Logs errori: `docker compose logs`

Per documentazione completa: https://developers.chatwoot.com/self-hosted/