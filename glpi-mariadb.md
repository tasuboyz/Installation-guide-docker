# Avvio del database MariaDB per GLPI

```bash
docker run --name mariadb \
  --network glpi-net \
  -e MARIADB_ROOT_PASSWORD='Atlanta96$$Tokio64%%' \
  -e MARIADB_DATABASE=glpidb \
  -e MARIADB_USER=glpi \
  -e MARIADB_PASSWORD=Caricatura.Rub \
  -e TZ=Europe/Rome \
  -v /etc/localtime:/etc/localtime:ro \
  -v mariadb-data:/var/lib/mysql \
  -d mariadb:10.7
```
