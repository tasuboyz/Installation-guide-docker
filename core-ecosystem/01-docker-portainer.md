# Installazione e avvio di Portainer

## Installazione di Docker

Per installare Docker su una macchina Linux, esegui i seguenti comandi:

```bash
curl -fsSL https://get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable docker
```

Al termine, puoi verificare l'installazione con:

```bash
docker --version
```

Se vedi la versione di Docker, l'installazione è andata a buon fine.

Portainer è un'interfaccia web per gestire facilmente Docker e i container. Si consiglia di installarlo per primo.

```bash
# Crea il volume per Portainer
docker volume create portainer_data

# Avvia Portainer
sudo docker run -d \
  -p 9443:9443 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

Accedi a Portainer dal browser:
```
https://<IP_SERVER>:9443
```
Segui la procedura guidata per creare l'utente admin e gestire i tuoi container Docker tramite interfaccia grafica.

## Esporre Portainer tramite `nginx-proxy` + Let's Encrypt

Se vuoi esporre Portainer con un sottodominio e gestire SSL automaticamente tramite `nginx-proxy` + `acme-companion`, puoi lanciare Portainer senza pubblicare le porte sull'host e lasciare la terminazione TLS al proxy.

Esempio (Portainer HTTP backend su `9000`, nginx-proxy si occupa di HTTPS):

```bash
docker run -d --name portainer \
  --network n8n-net \
  --restart unless-stopped \
  --expose 9000 \
  -e VIRTUAL_HOST=portainer-dr2.tasuthor.com \
  -e VIRTUAL_PORT=9000 \
  -e LETSENCRYPT_HOST=portainer-dr2.tasuthor.com \
  -e LETSENCRYPT_EMAIL=tasuhiro.davide@gmail.com \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

Note:
- Portainer espone la UI su `9000` (HTTP) e opzionalmente su `9443` (HTTPS) a seconda della versione/config.
- Se esponi `9000` internamente (`--expose 9000`) e imposti le env `VIRTUAL_HOST`/`VIRTUAL_PORT`/`LETSENCRYPT_*`, `nginx-proxy` rileverà il container e `acme-companion` richiederà il certificato.
- Se usi la UI HTTPS interna (`9443`) e non vuoi ricreare il container, lo script del proxy può usare un frammento `vhost.d` come fallback anziché ricreare il container.

### Verifiche rapide

1. Verifica DNS:

```bash
dig +short portainer-dr2.tasuthor.com
# deve restituire l'IP del server
```

2. Controlla le environment del container:

```bash
docker inspect portainer --format '{{json .Config.Env}}' | jq .
```

3. Monitora i log di `acme-companion` per lo stato del certificato:

```bash
docker logs -f nginx-proxy-acme
```

### Staging → Produzione (passaggi)

1) Se hai testato con il CA di staging, rimuovi `ACME_CA_URI` dal file `.env` in `applications/nginx-proxy/` (o impostalo vuoto) e riavvia `nginx-proxy-acme`:

```bash
cd applications/nginx-proxy
# modifica .env e rimuovi ACME_CA_URI
docker compose up -d nginx-proxy nginx-proxy-acme
```

2) (Opzionale) Se vuoi cancellare i dati di staging prima di richiedere certificati in produzione:

```bash
docker run --rm -v nginx-certs:/certs alpine sh -c "rm -rf /certs/*"
docker run --rm -v acme-state:/acme alpine sh -c "rm -rf /acme/*"
docker compose up -d nginx-proxy nginx-proxy-acme
```

3) Verifica emissione e accesso:

```bash
docker logs -f nginx-proxy-acme | grep portainer-dr2.tasuthor.com
curl -I https://portainer-dr2.tasuthor.com
```

Avvertenze:
- Let's Encrypt impone limiti di rate per certificati di produzione; usa il CA di staging per test ripetuti.
- Non richiedere certificati di produzione ripetutamente durante i test.

---

Se preferisci, posso aggiungere anche un esempio `docker compose` per Portainer che include le env `VIRTUAL_HOST`/`LETSENCRYPT_*` invece del comando `docker run`.
