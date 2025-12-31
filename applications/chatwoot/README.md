# Chatwoot Installation Setup

Questo repository fornisce un setup unificato per installare Chatwoot, una piattaforma self-hosted per il supporto clienti, utilizzando Docker con Redis e PostgreSQL come container.

## Quick Start

```bash
chmod +x install.sh
sudo ./install.sh
```

**Lo script fa tutto automaticamente:**
1. Configura rete Docker
2. Chiede il dominio (opzionale, per SSL automatico)
3. Chiede email Let's Encrypt (se dominio specificato)
4. Genera credenziali sicure (SECRET_KEY_BASE, password DB/Redis)
5. Crea `.env` e `docker-compose.yaml` configurati
6. Prepara il database e avvia i servizi

**NESSUN INTERVENTO MANUALE RICHIESTO** — niente modifiche a docker-compose, niente comandi extra.

## Modalità di Installazione

### Modalità Locale (default)
- Premi INVIO quando lo script chiede il dominio
- Chatwoot sarà accessibile su `http://<IP_SERVER>:3000`
- Nessun SSL (ideale per test o LAN)

### Modalità Dominio + SSL
- Inserisci il dominio quando richiesto (es. `chatwoot.example.com`)
- Inserisci l'email per Let's Encrypt
- Lo script configura automaticamente le variabili per `nginx-proxy` + `acme-companion`
- Il certificato SSL viene emesso automaticamente

## Struttura del Setup

- `install.sh`: Script di installazione guidata
- `.env`: File di configurazione ambiente (generato dallo script)
- `.env.example`: Template completo delle variabili ambiente
- `docker-compose.yaml`: Configurazione Docker Compose (generato/aggiornato dallo script)

## Servizi Containerizzati

Il setup include tutti i servizi come container Docker:

- **Rails App**: Applicazione principale Chatwoot
- **Sidekiq**: Worker per processi in background
- **PostgreSQL**: Database (con pgvector per funzionalità AI)
- **Redis**: Cache e message broker

## Requisiti

- Docker e Docker Compose installati
- Porta 3000 libera (modalità locale) oppure 80/443 (modalità proxy)
- DNS configurato e puntato al server (se usi dominio)
- `nginx-proxy` + `nginx-proxy-acme` in esecuzione (se usi dominio)

## Dopo l'Installazione

### Verifica servizi
```bash
docker compose ps
docker compose logs -f rails
```

### Verifica SSL (se hai configurato un dominio)
```bash
docker logs -f nginx-proxy-acme | grep chatwoot
curl -I https://chatwoot.tuodominio.com
```

### Accesso Rails console
```bash
docker exec -it $(basename $(pwd))-rails-1 sh -c 'RAILS_ENV=production bundle exec rails c'
```

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

# Logs
docker compose logs -f rails
```

## Troubleshooting

### Certificato non emesso
```bash
# Verifica che nginx-proxy e acme-companion siano attivi
docker ps | grep nginx-proxy

# Verifica che Chatwoot sia nella stessa rete del proxy
docker network inspect n8n-net

# Controlla i log di acme-companion
docker logs nginx-proxy-acme
```

### Servizio non raggiungibile
```bash
# Verifica stato servizi
docker compose ps

# Controlla logs errori
docker compose logs rails
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