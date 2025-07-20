# Installazione e avvio di Portainer

Portainer è un'interfaccia web per gestire facilmente Docker e i container. Si consiglia di installarlo per primo.

```bash
# Crea il volume per Portainer
docker volume create portainer_data

# Avvia Portainer
sudo docker run -d \
  -p 9000:9443 \
  -p 8000:8000 \
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
