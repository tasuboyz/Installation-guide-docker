# Guida: Compilazione ed Esecuzione di telegram-bot-api con Docker

Questa guida mostra come compilare e avviare il server `telegram-bot-api` usando Docker, senza dover installare manualmente le dipendenze sul sistema host.

## Metodo 1: Utilizzo di Dockerfile

### 1. Crea un file `Dockerfile` nella tua cartella di progetto:

```Dockerfile
FROM ubuntu:24.04

# Installazione delle dipendenze
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y make git zlib1g-dev libssl-dev gperf cmake clang-18 libc++-18-dev libc++abi-18-dev

# Clona il repository telegram-bot-api
RUN git clone --recursive https://github.com/tdlib/telegram-bot-api.git /telegram-bot-api

WORKDIR /telegram-bot-api

# Compila il progetto
RUN rm -rf build && \
    mkdir build && \
    cd build && \
    CXXFLAGS="-stdlib=libc++" CC=/usr/bin/clang-18 CXX=/usr/bin/clang++-18 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. .. && \
    cmake --build . --target install

# Espone la porta 8081 (default telegram-bot-api)
EXPOSE 8081

# Comando di avvio
CMD ["./bin/telegram-bot-api", "--help"]
```

### 2. Costruisci l'immagine Docker

```bash
docker build -t telegram-bot-api .
```

### 3. Avvia il container

```bash
docker run --name my-telegram-bot-api -p 8081:8081 telegram-bot-api
```

## Metodo 2: Utilizzo di Docker Compose

### 1. Crea un file `docker-compose.yml`:

```yaml
version: '3.8'

services:
  telegram-bot-api:
    build: .
    container_name: telegram-bot-api
    ports:
      - "8081:8081"
    restart: unless-stopped
```

### 2. Avvia il servizio

```bash
docker-compose up --build -d
```

## Note

- Puoi personalizzare i parametri di avvio modificando il comando in `CMD` nel Dockerfile o usando `docker run ... <opzioni>` (es: token, database, ecc).
- Per aggiornare la versione, ricostruisci l’immagine (`docker build ...`).
- I dati non sono persistenti: per la produzione, monta volumi per il database.

## Risorse

- [telegram-bot-api GitHub](https://github.com/tdlib/telegram-bot-api)
- [Documentazione ufficiale](https://core.telegram.org/bots/api)
