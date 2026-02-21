# OpenClaw AI Gateway

Gateway AI containerizzato con Docker. OpenClaw fornisce un gateway unificato per agenti AI con sandboxing, canali di comunicazione (WhatsApp, Telegram, Discord) e una Control UI web.

**Documentazione ufficiale:** [docs.openclaw.ai/install/docker](https://docs.openclaw.ai/install/docker)

---

## Requisiti

- Docker Desktop (o Docker Engine) + Docker Compose v2
- Spazio disco sufficiente per immagini e log (~2-3 GB)
- Porta 18789 disponibile (o personalizzabile)

---

## Installazione rapida (script guidato)

```bash
cd applications/openclaw
sudo ./install.sh
```

Lo script esegue automaticamente:
1. Verifica prerequisiti (Docker, Compose v2, openssl)
2. Configurazione rete Docker
3. Configurazione dominio + SSL (opzionale, via nginx-proxy)
4. Generazione token gateway
5. Opzioni avanzate (persistenza, pacchetti apt, sandbox)
6. Build immagine e onboarding
7. Avvio gateway

---

## Installazione manuale

### 1. Configurazione ambiente

```bash
cp .env.example .env
```

Modifica `.env` con i tuoi valori. Il token gateway viene generato automaticamente dallo script, oppure puoi generarlo manualmente:

```bash
openssl rand -hex 32
```

### 2. Build immagine

```bash
docker compose build
```

Con pacchetti apt aggiuntivi:

```bash
docker compose build --build-arg OPENCLAW_DOCKER_APT_PACKAGES="ffmpeg build-essential"
```

### 3. Onboarding

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli onboard
```

### 4. Avvio

```bash
docker compose up -d openclaw-gateway
```

### 5. Accesso dashboard

Apri `http://localhost:18789` nel browser e incolla il token (dal file `.env`) in **Settings > Token**.

Per ottenere l'URL dashboard:

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli dashboard --no-open
```

---

## Integrazione con nginx-proxy (SSL automatico)

Se usi il [reverse proxy](../nginx-proxy/README.md) del progetto, lo script `install.sh` configura automaticamente le variabili `VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST` e `LETSENCRYPT_EMAIL`.

Per configurazione manuale, aggiungi nel `.env`:

```bash
VIRTUAL_HOST=openclaw.example.com
VIRTUAL_PORT=18789
LETSENCRYPT_HOST=openclaw.example.com
LETSENCRYPT_EMAIL=admin@example.com
DOCKER_NETWORK=glpi-net
```

---

## Canali di comunicazione

Configura i canali dopo l'installazione tramite la CLI.

**WhatsApp (QR code):**

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli channels login
```

**Telegram:**

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli channels add --channel telegram --token "<BOT_TOKEN>"
```

**Discord:**

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli channels add --channel discord --token "<BOT_TOKEN>"
```

---

## Sandbox agenti

Il sandbox isola l'esecuzione dei tool degli agenti in container Docker separati.

### Build immagine sandbox

```bash
scripts/sandbox-setup.sh
```

### Configurazione

Il sandbox si configura tramite il file di configurazione del gateway (`~/.openclaw/config.json5`):

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main",
        scope: "agent",
        workspaceAccess: "none",
        docker: {
          image: "openclaw-sandbox:bookworm-slim",
          network: "none",
          memory: "1g",
          cpus: 1
        },
        prune: {
          idleHours: 24,
          maxAgeDays: 7
        }
      }
    }
  }
}
```

### Immagini sandbox disponibili

| Immagine | Descrizione |
|----------|-------------|
| `openclaw-sandbox:bookworm-slim` | Immagine base minimale |
| `openclaw-sandbox-common:bookworm-slim` | Con tooling sviluppo (Node, Go, Rust) |
| `openclaw-sandbox-browser:bookworm-slim` | Con Chromium + CDP + noVNC |

---

## Persistenza dati

| Volume | Contenuto |
|--------|-----------|
| `openclaw_config` | Configurazione gateway (`~/.openclaw/`) |
| `openclaw_workspace` | Workspace agenti (`~/.openclaw/workspace/`) |
| `openclaw_home` (opzionale) | Intero `/home/node` per cache e tool |

Per persistere `/home/node`:

```bash
export OPENCLAW_HOME_VOLUME="openclaw_home"
```

---

## Token e pairing dispositivi

Se vedi "unauthorized" o "disconnected (1008): pairing required":

```bash
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli dashboard --no-open
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli devices list
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli devices approve <requestId>
```

---

## Health check

```bash
docker compose exec openclaw-gateway node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

---

## Diagnostica

```bash
./diagnose.sh
```

Lo script verifica: file di configurazione, variabili ambiente, stato container, immagini, reti, volumi e raggiungibilità del gateway.

---

## Comandi utili

```bash
docker compose ps                                             # Stato servizi
docker compose logs -f openclaw-gateway                       # Log real-time
docker compose restart openclaw-gateway                       # Riavvia gateway
docker compose down                                           # Ferma tutto
docker compose down -v                                        # Ferma + rimuovi volumi
docker compose build --no-cache                               # Ricostruisci da zero
docker compose run --rm --entrypoint "node dist/cli.js" openclaw-cli devices list  # Lista dispositivi
```

---

## Permessi (EACCES)

L'immagine gira come utente `node` (uid 1000). Se ci sono errori di permessi:

```bash
sudo chown -R 1000:1000 /path/to/openclaw-config /path/to/openclaw-workspace
```

---

## Troubleshooting

| Problema | Soluzione |
|----------|----------|
| Immagine mancante | `docker compose build` o `scripts/sandbox-setup.sh` |
| Permessi EACCES | `chown -R 1000:1000` sui bind mount |
| "unauthorized" / pairing | Rigenera token con `openclaw-cli dashboard --no-open` |
| Container non parte | Verifica `.env` e log con `docker compose logs` |
| Tool custom non trovati | Imposta `docker.env.PATH` nel config sandbox |
| Porta occupata | Modifica `OPENCLAW_PORT` nel `.env` |

---

## Riferimenti

- [Documentazione ufficiale Docker](https://docs.openclaw.ai/install/docker)
- [Sandboxing](https://docs.openclaw.ai/gateway/sandboxing)
- [Dashboard](https://docs.openclaw.ai/web/dashboard)
- [Canali: WhatsApp](https://docs.openclaw.ai/channels/whatsapp), [Telegram](https://docs.openclaw.ai/channels/telegram), [Discord](https://docs.openclaw.ai/channels/discord)
