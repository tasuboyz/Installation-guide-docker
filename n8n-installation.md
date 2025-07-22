# Installazione n8n con Docker

## Panoramica
n8n è una piattaforma di automazione workflow che permette di connettere diversi servizi e automatizzare processi. Questa guida mostra come installarlo usando Docker con PostgreSQL come database.

## Prerequisiti
- Docker e Docker Compose installati
- Rete Docker condivisa (`glpi-net`)

## 1. Creazione della rete Docker (se non esiste già)
```bash
docker network create glpi-net
```

## 2. Installazione e avvio di PostgreSQL
```bash
docker run --name n8n-postgres \
  --network glpi-net \
  -e POSTGRES_USER=n8n \
  -e POSTGRES_PASSWORD=n8npass \
  -e POSTGRES_DB=n8ndb \
  -v n8n-postgres-data:/var/lib/postgresql/data \
  -d postgres:15
```

## 3. Avvio del container n8n
```bash
docker run --name n8n \
  --network glpi-net \
  -p 5678:5678 \
  -e DB_TYPE=postgresdb \
  -e DB_POSTGRESDB_HOST=n8n-postgres \
  -e DB_POSTGRESDB_PORT=5432 \
  -e DB_POSTGRESDB_DATABASE=n8ndb \
  -e DB_POSTGRESDB_USER=n8n \
  -e DB_POSTGRESDB_PASSWORD=n8npass \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=adminpass \
  -e N8N_SECURE_COOKIE=false \
  -v n8n-data:/home/node/.n8n \
  -d n8nio/n8n:latest
```

## 4. Accesso al servizio
- n8n: `http://<IP_SERVER>:5678`
- Username: `admin`
- Password: `adminpass`

## 5. Configurazione accesso a GLPI (MariaDB)
Per permettere a n8n di accedere al database di GLPI, configura una credenziale MySQL/MariaDB in n8n:

### Parametri di connessione:
- **Host**: `mariadb`
- **Database**: `glpidb`
- **User**: `glpi`
- **Password**: `Caricatura.Rub`
- **Porta**: `3306`

### Come configurare:
1. Accedi all'interfaccia n8n
2. Vai su "Credentials" nel menu principale
3. Clicca su "Create New"
4. Seleziona "MySQL" come tipo di credenziale
5. Inserisci i parametri sopra indicati
6. Testa la connessione e salva

## 6. Gestione dei dati persistenti
- Dati di n8n: volume `n8n-data`
- Dati di PostgreSQL: volume `n8n-postgres-data`

## 7. Comandi utili
```bash
# Fermare i servizi
docker stop n8n n8n-postgres

# Avviare i servizi
docker start n8n-postgres n8n

# Vedere i log
docker logs n8n
docker logs n8n-postgres

# Backup del database PostgreSQL
docker exec n8n-postgres pg_dump -U n8n n8ndb > n8n_backup.sql

# Ripristino del database PostgreSQL
docker exec -i n8n-postgres psql -U n8n -d n8ndb < n8n_backup.sql

# Accedere al database PostgreSQL
docker exec -it n8n-postgres psql -U n8n -d n8ndb
```

## 8. Variabili d'ambiente principali

### Autenticazione
```bash
N8N_BASIC_AUTH_ACTIVE=true          # Abilita autenticazione basic
N8N_BASIC_AUTH_USER=admin           # Username per l'accesso
N8N_BASIC_AUTH_PASSWORD=adminpass   # Password per l'accesso
```

### Database
```bash
DB_TYPE=postgresdb                  # Tipo di database
DB_POSTGRESDB_HOST=n8n-postgres     # Host del database
DB_POSTGRESDB_PORT=5432             # Porta del database
DB_POSTGRESDB_DATABASE=n8ndb        # Nome del database
DB_POSTGRESDB_USER=n8n              # Username database
DB_POSTGRESDB_PASSWORD=n8npass      # Password database
```

### Sicurezza
```bash
N8N_SECURE_COOKIE=false             # Cookie sicuri (true per HTTPS)
N8N_PROTOCOL=http                   # Protocollo (http/https)
N8N_PORT=5678                       # Porta di ascolto
```

## 9. Esempi di workflow per GLPI

### Workflow: Creazione automatica ticket
1. **Trigger**: Webhook o Email
2. **Database Query**: Inserimento in tabella `glpi_tickets`
3. **Notification**: Invio email di conferma

### Workflow: Monitoraggio scadenze
1. **Trigger**: Cron (scheduling)
2. **Database Query**: Query scadenze da GLPI
3. **Condition**: Verifica giorni rimanenti
4. **Notification**: Invio alert via email/Slack

### Workflow: Sincronizzazione utenti
1. **Trigger**: HTTP Request da sistema esterno
2. **Database Query**: Update/Insert utenti in GLPI
3. **Log**: Registrazione operazioni

## 10. Nodi utili per GLPI
- **MySQL Node**: Per query dirette al database GLPI
- **HTTP Request Node**: Per chiamate all'API REST di GLPI
- **Email Node**: Per notifiche
- **Cron Node**: Per automazioni schedulate
- **Webhook Node**: Per trigger esterni

## 11. Note di sicurezza
- **Cambia le credenziali di default** dopo l'installazione
- Esponi la porta 5678 solo su reti sicure
- Considera l'uso di HTTPS in produzione
- Limita l'accesso tramite reverse proxy se necessario
- Esegui backup regolari dei workflow e dati

## 12. Troubleshooting

### Container non si avvia
```bash
# Controlla i log
docker logs n8n
docker logs n8n-postgres

# Verifica la rete
docker network inspect glpi-net
```

### Database non raggiungibile
```bash
# Testa connessione PostgreSQL
docker exec -it n8n-postgres psql -U n8n -d n8ndb -c "\l"

# Testa connessione a MariaDB da n8n
docker exec -it n8n ping mariadb
```

### Problemi di autenticazione
- Verifica le variabili d'ambiente `N8N_BASIC_AUTH_*`
- Controlla che le credenziali siano corrette
- Riavvia il container dopo modifiche alle variabili

### Workflow non funzionanti
- Controlla i log del workflow specifico
- Verifica le credenziali dei database
- Testa le connessioni manualmente

## 13. Riferimenti
- [n8n Docker](https://hub.docker.com/r/n8nio/n8n)
- [PostgreSQL Docker](https://hub.docker.com/_/postgres)
- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [GLPI API Documentation](https://github.com/glpi-project/glpi/blob/master/apirest.md)
