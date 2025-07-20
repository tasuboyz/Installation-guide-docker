# Creazione volume dati per GLPI

```bash
docker create --name glpi-data \
  -v /var/www/html/glpi \
  diouxx/glpi /bin/true
```
