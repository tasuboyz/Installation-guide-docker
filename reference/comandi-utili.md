# Comandi utili

- Fermare un container: `docker stop <nome_container>`
- Avviare un container: `docker start <nome_container>`
- Aggiornare un container: `docker pull <image>` e ricreare il container

- Trasferire una cartella dal PC al server Linux:
  `scp -r /percorso/cartella username@server:/percorso/destinazione`

- Copiare una cartella dal server Linux a un container Docker:
  `docker cp /percorso/cartella <nome_container>:/percorso/destinazione`
