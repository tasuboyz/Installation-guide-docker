# Avvio di PostgreSQL per n8n

```bash
docker run --name n8n-postgres \
  --network glpi-net \
  -e POSTGRES_USER=n8n \
  -e POSTGRES_PASSWORD=n8npass \
  -e POSTGRES_DB=n8ndb \
  -v n8n-postgres-data:/var/lib/postgresql/data \
  -d postgres:15
```
