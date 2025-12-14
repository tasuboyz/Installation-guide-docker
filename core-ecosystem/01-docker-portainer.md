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
https://<IP_SERVER>:9000
```
Segui la procedura guidata per creare l'utente admin e gestire i tuoi container Docker tramite interfaccia grafica.
