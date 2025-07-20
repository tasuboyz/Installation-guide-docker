# Avvio di n8n

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
