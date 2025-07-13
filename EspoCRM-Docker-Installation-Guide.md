# Guida all'Installazione di EspoCRM con Docker

## Panoramica
Questa guida descrive come installare EspoCRM utilizzando Docker con un database MariaDB. EspoCRM è un CRM open-source moderno e facile da usare.

## Prerequisiti

- **Docker** installato sul sistema
- **Docker Compose** (opzionale, ma consigliato)
- Porta **8083** disponibile sul sistema host
- Almeno **2GB di RAM** disponibili
- **5GB di spazio disco** libero

## Metodo 1: Installazione con Docker Network (Raccomandato)

### Passo 1: Creare la rete Docker personalizzata

```bash
docker network create espocrm-net
```

### Passo 2: Avviare il container MariaDB

```bash
docker run --name mariadb \
  --network espocrm-net \
  -e MYSQL_ROOT_PASSWORD=supersecurepassword \
  -e MYSQL_DATABASE=espocrm \
  -e MYSQL_USER=espouser \
  -e MYSQL_PASSWORD=espopassword \
  -v mariadb-data:/var/lib/mysql \
  -d mariadb:latest
```

**Parametri spiegati:**
- `--name mariadb`: Nome del container
- `--network espocrm-net`: Connessione alla rete personalizzata
- `-e MYSQL_ROOT_PASSWORD`: Password dell'utente root di MySQL
- `-e MYSQL_DATABASE`: Nome del database da creare
- `-e MYSQL_USER`: Utente MySQL per EspoCRM
- `-e MYSQL_PASSWORD`: Password dell'utente MySQL
- `-v mariadb-data:/var/lib/mysql`: Volume persistente per i dati
- `-d`: Esecuzione in background

### Passo 3: Avviare il container EspoCRM

```bash
docker run --name my-espocrm \
  --network espocrm-net \
  -p 8083:80 \
  -v espocrm-data:/var/www/html \
  -d espocrm/espocrm:latest
```

**Parametri spiegati:**
- `--name my-espocrm`: Nome del container EspoCRM
- `--network espocrm-net`: Connessione alla stessa rete del database
- `-p 8083:80`: Mappatura porta host:container
- `-v espocrm-data:/var/www/html`: Volume persistente per i file EspoCRM
- `-d`: Esecuzione in background

### Passo 4: Verificare l'installazione

1. Attendere circa 2-3 minuti per l'avvio completo
2. Aprire il browser e navigare a: `http://localhost:8083`
3. Seguire la procedura guidata di setup

## Metodo 2: Installazione con Docker Compose (Alternativo)

### Passo 1: Creare il file docker-compose.yml

```yaml
version: '3.8'

services:
  mariadb:
    image: mariadb:latest
    container_name: espocrm-mariadb
    environment:
      MYSQL_ROOT_PASSWORD: supersecurepassword
      MYSQL_DATABASE: espocrm
      MYSQL_USER: espouser
      MYSQL_PASSWORD: espopassword
    volumes:
      - mariadb-data:/var/lib/mysql
    networks:
      - espocrm-network
    restart: unless-stopped

  espocrm:
    image: espocrm/espocrm:latest
    container_name: espocrm-app
    ports:
      - "8083:80"
    volumes:
      - espocrm-data:/var/www/html
    networks:
      - espocrm-network
    depends_on:
      - mariadb
    restart: unless-stopped

volumes:
  mariadb-data:
  espocrm-data:

networks:
  espocrm-network:
    driver: bridge
```

### Passo 2: Avviare i servizi

```bash
docker-compose up -d
```

## Configurazione Iniziale EspoCRM

### Parametri di Configurazione Database

Quando si accede per la prima volta a `http://localhost:8083`, utilizzare questi parametri:

- **Database Host**: `mariadb` (nome del container)
- **Database Name**: `espocrm`
- **Database User**: `espouser`
- **Database Password**: `espopassword`
- **Database Port**: `3306`

### Creazione Account Amministratore

Durante il setup guidato, creare:
- **Username amministratore**: (a scelta)
- **Password amministratore**: (scegliere una password sicura)
- **Email amministratore**: (inserire email valida)

## Comandi Utili per la Gestione

### Visualizzare i log dei container

```bash
# Log EspoCRM
docker logs my-espocrm -f

# Log MariaDB
docker logs mariadb -f
```

### Arrestare i servizi

```bash
# Arrestare i container
docker stop my-espocrm mariadb

# Con Docker Compose
docker-compose down
```

### Riavviare i servizi

```bash
# Riavviare i container
docker start mariadb
docker start my-espocrm

# Con Docker Compose
docker-compose restart
```

### Accesso al container per manutenzione

```bash
# Accedere al container EspoCRM
docker exec -it my-espocrm bash

# Accedere al container MariaDB
docker exec -it mariadb bash
```

### Correzione permessi file

```bash
# Entrare nel container EspoCRM
docker exec -it my-espocrm bash

# Correggere i permessi
cd /var/www/html
find data -type d -exec chmod 775 {} +
chown -R 33:33 .
```

### Backup del database

```bash
docker exec mariadb mysqldump -u root -psupersecurepassword espocrm > backup_espocrm_$(date +%Y%m%d_%H%M%S).sql
```

### Ripristino del database

```bash
docker exec -i mariadb mysql -u root -psupersecurepassword espocrm < backup_espocrm_YYYYMMDD_HHMMSS.sql
```

## Risoluzione Problemi

### Problema: Container non si avvia

**Soluzione:**
1. Verificare che le porte non siano già in uso
2. Controllare i log: `docker logs <nome-container>`
3. Verificare che Docker abbia abbastanza risorse

### Problema: Impossibile connettersi al database

**Soluzione:**
1. Verificare che i container siano nella stessa rete
2. Controllare le credenziali del database
3. Attendere che MariaDB sia completamente avviato

### Problema: Errore 500 su EspoCRM

**Soluzione:**
1. Verificare i permessi sui volumi
2. Controllare i log di EspoCRM
3. Riavviare il container EspoCRM

### Problema: Errori di permessi sui file

**Soluzione (Raccomandato):**
Se si verificano errori di permessi o problemi di scrittura file, connettersi al container ed eseguire i comandi di correzione:

```bash
# Accedere al container EspoCRM
docker exec -it my-espocrm bash

# Una volta dentro il container, eseguire:
cd /var/www/html
find data -type d -exec chmod 775 {} +
chown -R 33:33 .
```

**Spiegazione comandi:**
- `docker exec -it my-espocrm bash`: Accede al container in modalità interattiva
- `find data -type d -exec chmod 775 {} +`: Imposta permessi 775 su tutte le directory in data/
- `chown -R 33:33 .`: Cambia proprietario ricorsivamente (33:33 = www-data user/group)

## Sicurezza

### Raccomandazioni di Sicurezza

1. **Cambiare le password di default** prima della produzione
2. **Utilizzare HTTPS** in produzione (con reverse proxy)
3. **Limitare l'accesso alle porte** del database
4. **Backup regolari** del database e dei file
5. **Aggiornamenti periodici** delle immagini Docker

### Esempio configurazione con reverse proxy (Nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8083;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Aggiornamenti

### Aggiornare EspoCRM

```bash
# Arrestare il container
docker stop my-espocrm

# Rimuovere il container (i dati rimangono nel volume)
docker rm my-espocrm

# Scaricare l'immagine aggiornata
docker pull espocrm/espocrm:latest

# Ricreare il container con la nuova immagine
docker run --name my-espocrm \
  --network espocrm-net \
  -p 8083:80 \
  -v espocrm-data:/var/www/html \
  -d espocrm/espocrm:latest
```

## Risorse Utili

- **Documentazione Ufficiale EspoCRM**: https://docs.espocrm.com/
- **Docker Hub EspoCRM**: https://hub.docker.com/r/espocrm/espocrm
- **Community Forum**: https://forum.espocrm.com/
- **GitHub Repository**: https://github.com/espocrm/espocrm

---

**Data di creazione**: 12 Luglio 2025  
**Versione guida**: 1.0  
**Testato con**: Docker 24.x, EspoCRM 8.x, MariaDB 11.x
