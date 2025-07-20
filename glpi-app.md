# Avvio del container GLPI

```bash
docker run --name glpi \
  --network glpi-net \
  --volumes-from glpi-data \
  -p 81:80 \
  -e TIMEZONE=Europe/Rome \
  -d diouxx/glpi
```
