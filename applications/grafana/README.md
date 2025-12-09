# Installazione Grafana con Docker

## Panoramica
Grafana è una piattaforma open source per la visualizzazione e l'analisi di dati tramite dashboard interattive. Questa guida mostra come installare e avviare Grafana utilizzando Docker.

## Prerequisiti
- Docker installato
- (Opzionale) Docker Compose installato
- (Opzionale) Rete Docker condivisa se si collega a database esterni

## 1. Creazione volume dati persistenti
Per mantenere i dati e le configurazioni di Grafana anche dopo il riavvio o la rimozione del container:

```bash
docker volume create grafana-data
```

## 2. (Opzionale) Creazione rete Docker
Se vuoi collegare Grafana ad altri servizi (es. database) tramite una rete dedicata:

```bash
docker network create monitoring-net
```

## 3. Avvio del container Grafana

```bash
docker run -d \
  --name=grafana \
  -p 3000:3000 \
  --network monitoring-net \
  -v grafana-data:/var/lib/grafana \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e GF_SECURITY_ADMIN_PASSWORD=Grafana!2025$# \
  grafana/grafana-oss:latest
```

- Accedi a Grafana da browser: [http://localhost:3000](http://localhost:3000) (o `http://<IP_SERVER>:3000`)
- Username: `admin`
- Password: `Grafana!2025$#`

## 4. Configurazione iniziale
1. Al primo accesso, effettua il login con le credenziali sopra.
2. Segui la procedura guidata per cambiare la password e aggiungere le prime fonti dati (es. MySQL, PostgreSQL, Prometheus, ecc).
3. Crea la tua prima dashboard.

## 5. Gestione dati persistenti
- Tutti i dati e le configurazioni sono salvati nel volume `grafana-data`.

## 6. Comandi utili
```bash
# Fermare Grafana
docker stop grafana

# Avviare Grafana
docker start grafana

# Aggiornare Grafana
docker pull grafana/grafana-oss:latest
docker stop grafana
docker rm grafana
docker run ... (come sopra)

# Visualizzare i log
docker logs grafana
```

## 7. Note di sicurezza
- Cambia la password di default dopo il primo accesso
- Esporre la porta 3000 solo su reti sicure
- Considera l'uso di HTTPS in produzione
- Esegui backup regolari del volume `grafana-data`

## 8. Riferimenti
- [Grafana Docker Hub](https://hub.docker.com/r/grafana/grafana-oss)
- [Documentazione ufficiale Grafana](https://grafana.com/docs/grafana/latest/)
