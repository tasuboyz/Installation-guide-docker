# Installazione GLPI con Docker

## Prerequisiti
- Rete Docker creata: `docker network create glpi-net`

## 1. Avvio del database MariaDB per GLPI

```bash
docker run --name mariadb \
  --network glpi-net \
  -e MARIADB_ROOT_PASSWORD='SecureRoot2024!!' \
  -e MARIADB_DATABASE=glpidb \
  -e MARIADB_USER=glpi \
  -e MARIADB_PASSWORD='GlpiPass2024#' \
  -e TZ=Europe/Rome \
  -v /etc/localtime:/etc/localtime:ro \
  -v mariadb-data:/var/lib/mysql \
  -d mariadb:10.7
```

## 2. Creazione volume dati per GLPI

```bash
docker create --name glpi-data \
  -v /var/www/html/glpi \
  diouxx/glpi /bin/true
```

## 3. Avvio del container GLPI

```bash
docker run --name glpi \
  --network glpi-net \
  --volumes-from glpi-data \
  -p 81:80 \
  -e TIMEZONE=Europe/Rome \
  -d diouxx/glpi
```

## 4. Accesso a GLPI

- URL: `http://<IP_SERVER>:81`

## 5. Configurazione Database durante il setup

Durante la configurazione iniziale di GLPI, utilizzare questi parametri:
- **Database Host**: `mariadb`
- **Database Name**: `glpidb`
- **Database User**: `glpi`
- **Database Password**: `GlpiPass2024#`
- **Database Port**: `3306`
