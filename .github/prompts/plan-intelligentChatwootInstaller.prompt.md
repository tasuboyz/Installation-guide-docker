# Plan: Sistema di Installazione Intelligente e Guidata per Docker

**TL;DR**: Creare uno script bash interattivo centralizzato per Linux che:
- Scansioni e rilevi servizi/container esistenti (PostgreSQL, Redis, Nginx, Certbot)
- Guidi l'utente nella scelta di cosa installare (Chatwoot, Portainer, GLPI, etc.)
- **Scarichi e configuri progetti personalizzati** da repository Git
- Configuri dominio, SSL/TLS con Certbot e Nginx come reverse proxy **centralizzato per tutti i progetti**
- **Gestisca dipendenze condivise** (Redis/PostgreSQL) intelligentemente (container condivisi vs dedicati)
- Generi un `.env.master` centralizzato replicabile su più server
- Orchi la deployment di tutti i servizi in un unico flusso

## Implementation Steps

### 1. Script di Rilevamento Sistema (`detect.sh`)
Scansioni:
- OS (Linux) e distribuzione
- Docker/Docker Compose installati
- Container/servizi già in esecuzione (postgres, redis, nginx, certbot)
- Porte occupate (80, 443, 3000, 5432, 6379)
- Dominio/certificati SSL esistenti

**Output**: JSON con stato del sistema

### 2. Modulo Configurazione Interattiva (`interactive-setup.sh`)
Che:
- Menu guidato per scegliere componenti (Chatwoot ☑, Portainer ☐, GLPI ☐, Custom Projects ☐)
- **Per progetti personalizzati**: chieda URL Git repository, branch/tag, cartella destinazione
- Chieda dominio principale e sottodomini (uno per ogni progetto)
- Validi email/credenziali utente
- Generi password randomiche una sola volta (riutilizzabili)
- Salvi le scelte in file JSON di stato

**Input**: Dialogo utente
**Output**: `setup-config.json` con scelte, credenziali e lista progetti

### 3. Modulo Download Progetti Personalizzati (`download-projects.sh`)
**NUOVO - AGGIORNATO CON STRATEGIA "DOCKER COMPOSE ONLY"** - Che:
- Cloni repository Git dei progetti custom (public/private SSH)
- **Ignori script di installazione custom** (es. `install.sh`, `setup.py`) per sicurezza
- **Usa SOLO `docker-compose.yml`** del progetto:
  - Parsing per estrarre services, ports, volumes, environment, networks
  - Se mancante: chiedi input utente o genera template
- Scansioni dipendenze dichiarate (Redis, PostgreSQL, MongoDB, etc.) da docker-compose.yml
- Rilevi conflitti (porte già usate, nomi volumi duplicati)
- Chieda all'utente se usare container condivisi o dedicati per ogni dipendenza
- Salvi configurazione dipendenze in `setup-config.json`

**Input**: `setup-config.json` (lista progetti Git URLs)
**Output**: 
- Progetti clonati in `/opt/projects/<nome>`
- Dipendenze mappate (shared vs dedicated)
- Conflitti risolti (port remapping, volume renaming)
- `docker-compose.override.yml` generato per ogni progetto

### 4. Modulo Gestione Dipendenze Condivise (`dependencies-manager.sh`)
**NUOVO** - Che:
- Analizzi tutte le dipendenze da tutti i progetti
- Proponga strategia ottimale:
  - **Condivisi**: Un solo container PostgreSQL/Redis per tutti (con DB/keyspace multipli)
  - **Dedicati**: Container separati per ogni progetto
  - **Misti**: Condividi dove possibile, separa dove necessario
- Generi configurazione Docker Compose per dipendenze condivise
- Crei database/utenti/keyspace per ogni progetto

**Input**: `setup-config.json` (dipendenze mappate)
**Output**: `docker-compose.dependencies.yml` + script init per DB

### 5. Modulo SSL/TLS (`ssl-setup.sh`)
Che:
- Verifichi certificati Certbot esistenti
- Installi/rinnovi certificati per **tutti i sottodomini** (progetti + Chatwoot + altro)
- Configuri auto-renewal
- Generi file config Nginx con wildcard/SNI

**Dipende da**: Dominio/sottodomini da `setup-config.json`
**Output**: Certificati in `/etc/letsencrypt/live/` + config Nginx

### 6. Orchestrazione Nginx Centralizzata (`nginx-setup.sh`)
Che:
- **Generi config reverse proxy per OGNI progetto** (Chatwoot, custom projects, Portainer, GLPI)
- Mapping sottodominio → backend service (es. `chat.domain.com` → `http://chatwoot-rails:3000`)
- Passi gli header corretti (X-Forwarded-*, X-Real-IP)
- Gestisca WebSocket upgrade (per chat real-time, n8n, etc.)
- Configurazione rate limiting per endpoint pubblici
- Mantenga stato dei servizi backend

**Dipende da**: `setup-config.json` + certificati SSL + progetti scaricati
**Output**: `/etc/nginx/conf.d/<progetto>-*.conf` per ogni servizio + reload Nginx

### 7. Generazione `.env.master` Centralizzato
Con:
- Password/chiavi generate una volta, riutilizzate da tutti i servizi
- URL/domini per ogni componente (inclusi progetti custom)
- **Credenziali per dipendenze condivise** (PostgreSQL users, Redis keyspaces)
- Configurazione SMTP, storage, secrets
- Variabili specifiche per ogni container
- **Mapping progetto → dipendenze** (quale progetto usa quale DB/Redis)

**Dipende da**: `setup-config.json` + dipendenze mappate
**Output**: `.env.master` nella cartella root del progetto

### 8. Docker Compose Globale (`docker-compose.yml` master)
Che:
- Includa **dipendenze condivise** (PostgreSQL, Redis shared)
- Includa tutti i servizi predefiniti (Chatwoot Rails/Sidekiq, Nginx, Portainer, etc.)
- **Include progetti personalizzati** tramite `docker-compose.override.yml` o extending
- Usi variabili da `.env.master`
- Definisca dipendenze corrette (health checks, depends_on)
- Gestisca volumi persistenti per DB/certificati/storage progetti
- Crei network condivisa (`app-network`) per comunicazione inter-service

**Dipende da**: `.env.master` + rilevamento servizi esistenti + progetti scaricati
**Output**: Stack Docker orchestrato e avviato

### 9. Script di Orchestrazione Master (`install.sh`)
Che:
- Esegua tutti i moduli in sequenza
- Gestisca errori e rollback parziali
- Fornisca output colorato con progressi
- Salvi log delle operazioni

**Flow**:
```
install.sh
├─ check prerequisites (docker, openssl, curl, git)
├─ detect.sh → system-state.json
├─ interactive-setup.sh → setup-config.json (include custom projects)
├─ download-projects.sh → clone Git repos + scan dependencies
├─ dependencies-manager.sh → decide shared vs dedicated containers
├─ ssl-setup.sh → certificates for ALL subdomains
├─ nginx-setup.sh → centralized reverse proxy for ALL projects
├─ generate .env.master → include custom projects vars
├─ docker compose up -d → start shared dependencies first
├─ docker compose -f projects/<name>/docker-compose.yml up -d (for each)
└─ health checks + summary (all endpoints)
```



## Existing Solutions Analysis

### Software che fanno cose simili

#### 1. **nginx-proxy + acme-companion** 🔥 (Più rilevante)
**Repository**: https://github.com/nginx-proxy/nginx-proxy + https://github.com/nginx-proxy/acme-companion

**Cosa fa**:
- ✅ Reverse proxy automatico per container Docker
- ✅ Certificati SSL automatici con Let's Encrypt/ACME
- ✅ Auto-discovery: basta aggiungere `VIRTUAL_HOST` e `LETSENCRYPT_HOST` env vars ai container
- ✅ Reload Nginx automatico quando container start/stop
- ✅ Supporto wildcard certificates (con DNS-01)
- ✅ Multi-domain (SAN) certificates

**Come funziona**:
```bash
# Step 1: Avvia nginx-proxy
docker run -d \
  --name nginx-proxy \
  -p 80:80 -p 443:443 \
  -v /var/run/docker.sock:/tmp/docker.sock:ro \
  nginxproxy/nginx-proxy

# Step 2: Avvia acme-companion
docker run -d \
  --name nginx-proxy-acme \
  --volumes-from nginx-proxy \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e DEFAULT_EMAIL=mail@domain.com \
  nginxproxy/acme-companion

# Step 3: Avvia container con env vars
docker run -d \
  -e VIRTUAL_HOST=app.domain.com \
  -e LETSENCRYPT_HOST=app.domain.com \
  -e VIRTUAL_PORT=3000 \
  my-app
```

**Pro**:
- ✅ Automatico al 100%: zero configurazione manuale
- ✅ Certificati SSL automatici con renewal
- ✅ Maturo e testato (19.7k stars)
- ✅ Funziona con qualsiasi container Docker

**Contro**:
- ❌ Non gestisce dipendenze condivise (PostgreSQL, Redis)
- ❌ Non fa download progetti Git
- ❌ Non gestisce installazione guidata
- ❌ Richiede che ogni container abbia env vars corrette

**Conclusione**: **Possiamo integrarlo** nel nostro script! Invece di scrivere Nginx config manualmente, usiamo nginx-proxy.

---

#### 2. **Traefik** (Alternativa moderna)
**Repository**: https://github.com/traefik/traefik

**Cosa fa**:
- ✅ Reverse proxy e load balancer automatico
- ✅ Certificati SSL automatici con Let's Encrypt
- ✅ Auto-discovery Docker/Kubernetes/Consul/etc.
- ✅ Dashboard web per monitoring
- ✅ Middleware per rate limiting, auth, etc.

**Come funziona**:
```yaml
# docker-compose.yml
services:
  traefik:
    image: traefik:v2.10
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.myresolver.acme.email=mail@domain.com
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  my-app:
    image: my-app
    labels:
      - traefik.http.routers.my-app.rule=Host(`app.domain.com`)
      - traefik.http.routers.my-app.tls.certresolver=myresolver
```

**Pro**:
- ✅ Moderno e performante
- ✅ Dashboard grafica
- ✅ Più features (rate limiting, middleware)

**Contro**:
- ❌ Configurazione più complessa (labels vs env vars)
- ❌ Non gestisce dipendenze condivise
- ❌ Non fa download progetti Git

**Conclusione**: Alternativa valida a nginx-proxy, ma più complesso per utenti non esperti.

---

#### 3. **Coolify** (Self-hosted PaaS)
**Repository**: https://github.com/coollabsio/coolify

**Cosa fa**:
- ✅ Deploy automatico da Git repos
- ✅ SSL automatico
- ✅ Database management (PostgreSQL, Redis, etc.)
- ✅ Dashboard web completa
- ✅ Backup automatici

**Pro**:
- ✅ Tutto in uno (simile a Heroku/Vercel)
- ✅ UI grafica completa

**Contro**:
- ❌ Troppo complesso per setup semplici
- ❌ Richiede installazione di Coolify stesso
- ❌ Meno flessibile (opinonated)

**Conclusione**: Ottimo per PaaS completo, ma non adatto per il nostro caso d'uso.

---

### 💡 Strategia Proposta: Ibrido

**Invece di reinventare la ruota**, possiamo:

1. **Usare nginx-proxy + acme-companion** per reverse proxy e SSL
   - Già testato e maturo
   - Auto-discovery automatico
   - Zero configurazione manuale Nginx

2. **Il nostro script si occupa di**:
   - ✅ Installazione guidata (dominio, email, componenti)
   - ✅ Download progetti Git (public/private)
   - ✅ Gestione dipendenze condivise (PostgreSQL, Redis)
   - ✅ Generazione `.env.master` centralizzato
   - ✅ Orchestrazione docker-compose globale
   - ✅ Setup nginx-proxy + acme-companion
   - ✅ Iniettare `VIRTUAL_HOST` e `LETSENCRYPT_HOST` nei container

**Vantaggi**:
- ✅ Riduciamo complessità (no script Nginx custom)
- ✅ SSL automatico senza scrivere codice Certbot
- ✅ Nginx reload automatico
- ✅ Focus su orchestrazione e dipendenze condivise

---

## Further Considerations

### 1. Gestione Script di Installazione Custom dei Progetti
**NUOVO - PROBLEMA IDENTIFICATO DALL'UTENTE** - **Domande**:
- Molti progetti custom hanno **propri script di installazione** (es. `install.sh`, `setup.py`)
- Come integrarli senza conflitti?
  - **Opzione A**: Ignora script custom, usa solo `docker-compose.yml` del progetto
  - **Opzione B**: Esegui script custom in sandbox, poi integra risultato
  - **Opzione C**: Parsing script custom per estrarre comandi Docker
- Cosa fare se lo script custom richiede input interattivo?
  - Pre-generare risposte da `setup-config.json`?
  - Eseguire in modo non-interattivo con defaults?
- Come gestire conflitti di porte/volumi?
  - Script custom potrebbe usare porte già occupate
  - Potrebbe creare volumi con nomi conflittuali

**Proposta - Strategia "Docker Compose Only"**:
1. **Non eseguire script custom** - potrebbero essere pericolosi o incompatibili
2. **Usa solo `docker-compose.yml` del progetto**:
   - Parsing per estrarre services, ports, volumes, networks
   - Merge nel `docker-compose.yml` globale
   - Remap porte se già occupate (es. 3000 → 3001)
3. **Se non c'è docker-compose.yml**:
   - Chiedi all'utente di fornirlo manualmente
   - Oppure genera template base (Dockerfile + esposizione porta)
4. **Variabili ambiente**:
   - Inietta variabili da `.env.master` sovrascrivendo `.env` del progetto
   - Passa credenziali dipendenze condivise
5. **Post-install hooks** (opzionale):
   - Se progetto ha `post-install.sh`, eseguilo **dopo** che container è up
   - In ambiente controllato (dentro il container stesso)

**Esempio Flow**:
```bash
# Progetto custom clonato in /opt/projects/my-app
cd /opt/projects/my-app

# 1. Scansiona docker-compose.yml
services=$(parse_docker_compose docker-compose.yml)

# 2. Rileva conflitti porte
if port_in_use 3000; then
  remap_port 3000 3001
fi

# 3. Inietta env vars
generate_env_from_master > .env

# 4. Aggiungi VIRTUAL_HOST per nginx-proxy
echo "VIRTUAL_HOST=myapp.domain.com" >> .env
echo "LETSENCRYPT_HOST=myapp.domain.com" >> .env

# 5. Merge nel docker-compose globale
merge_compose docker-compose.yml ../docker-compose.global.yml

# 6. Avvia container
docker compose -f ../docker-compose.global.yml up -d my-app

# 7. Post-install hook (se esiste)
if [ -f post-install.sh ]; then
  docker exec my-app bash /app/post-install.sh
fi
```

**Rischi e Mitigazioni**:
| Rischio | Mitigazione |
|---------|-------------|
| Script custom dannoso | Non eseguire script, usa solo docker-compose.yml |
| docker-compose.yml mancante | Chiedi input utente o genera template |
| Dipendenze hardcoded | Sovrascrive con variabili da .env.master |
| Porte conflittuali | Auto-remap con offset (3000→3001→3002...) |
| Nomi volumi duplicati | Prefix con nome progetto (myapp_data) |
| Network incompatibili | Forza tutti su network condivisa (app-network) |

### 2. Gestione Dipendenze Condivise (Redis/PostgreSQL)
**NUOVO** - **Domande**:
- Quando usare container condivisi vs dedicati?
  - **Condiviso**: Migliore per risorse limitate, più semplice backup
  - **Dedicato**: Migliore per isolamento, performance, versioni diverse
- Come gestire database multipli in PostgreSQL condiviso?
  - Creare un database per progetto con utente dedicato
  - Schema: `<progetto>_production` (es. `chatwoot_production`, `n8n_production`)
- Come gestire keyspace Redis condivisi?
  - Usare prefix per chiavi (es. `chatwoot:`, `custom_project:`)
  - Oppure Redis databases numerici (0-15)
- Gestione versioni differenti?
  - Se progetti richiedono versioni diverse di PostgreSQL/Redis → container dedicati
  - Altrimenti → container condiviso con versione più recente compatibile

**Proposta**:
- Script chiede per ogni dipendenza: "Usare container condiviso o dedicato?"
- Default intelligente:
  - **PostgreSQL**: Condiviso (multi-database) se stessa versione major
  - **Redis**: Condiviso (multi-keyspace) sempre
  - **MongoDB/MySQL/altro**: Dedicato (meno comune)
- Generare `docker-compose.dependencies.yml` dinamicamente
- Script init SQL per creare DB/users automaticamente

### 3. Download e Configurazione Progetti Personalizzati
**NUOVO - AGGIORNATO** - **Domande**:
- Formato repository Git supportati?
  - ✅ Public repos (https clone)
  - ✅ Private repos (SSH keys) - **confermato**
- Dove salvare progetti?
  - `/opt/projects/<nome>`? Cartella utente? - ❓ Default `/opt/projects/`
- Come rilevare dipendenze?
  - ✅ **Parsing SOLO `docker-compose.yml`** (strategia confermata)
  - ❌ Ignorare script custom (pericolosi)
  - Se mancante docker-compose.yml: chiedi input utente
- Come integrare in Docker Compose globale?
  - ✅ **Merging dinamico** nel compose master
  - Genera `docker-compose.override.yml` per ogni progetto
  - Network condivisa (`app-network`) per tutti
  - Inietta `VIRTUAL_HOST` e `LETSENCRYPT_HOST` per nginx-proxy

**Proposta AGGIORNATA**:
1. **Clone Git**:
   - Public repos: `git clone https://...`
   - Private repos: `git clone git@github.com:...` (SSH key setup guidato)
2. **Parsing docker-compose.yml**:
   - Estrai services, ports, volumes, depends_on
   - Rileva dipendenze (postgres, redis, mysql, mongo)
   - Se mancante: genera template o chiedi input
3. **Conflict Resolution**:
   - Port remapping: 3000→3001 se già occupata
   - Volume renaming: `data` → `myapp_data`
   - Network: forza `app-network` condivisa
4. **Environment Injection**:
   - Genera `.env` da `.env.master`
   - Aggiungi `VIRTUAL_HOST` e `LETSENCRYPT_HOST`
   - Passa credenziali dipendenze condivise
5. **Merge Compose**:
   - Aggiungi services al `docker-compose.global.yml`
   - Usa `extends` per riutilizzare config
   - Dependency ordering corretto

### 4. Stato Persistente e Idempotenza
**Domande**:
- Dovremmo salvare uno state file (JSON) per tracciare cosa è già installato e permettere il re-run dello script senza reimpostare tutto?
- Come gestire aggiornamenti/modifiche di configurazione post-installazione?
- Dovrebbe lo script essere idempotente (safe to run multiple times)?

**Proposta**: 
- Salvare `.installation-state.json` che traccia:
  - Timestamp di ultima esecuzione
  - Hash di `.env.master` (rilevare modifiche)
  - Versioni componenti installati
  - Certificati SSL in scadenza (pre-renewal warnings)
- Permettere flag `--skip-config` per riusare setup precedente
- Permettere flag `--reconfigure` per cambiare solo alcuni parametri

### 4. Backup e Recovery
**Domande**:
- Salvare backup automatici del `.env.master` e certificati?
- Aggiungere script di backup/restore dei volumi Docker (database, storage)?
- Qual è la strategia di recovery in caso di fallimento?

**Proposta**:
- Script `backup.sh` che archivi:
  - `.env.master` (criptato con password?)
  - Certificati Letsencrypt
  - DB PostgreSQL dump
  - Configurazioni Nginx
- Creare cartella `backups/` con rotazione (keep only N days)
- Script `restore.sh` per recovery da backup

### 5. Testing e Validazione
**Domande**:
- Aggiungere health checks post-deploy?
- Script di test della configurazione SSL/Nginx?
- Come verificare che i sottodomini risolvono correttamente?

**Proposta**:
- `health-check.sh` che testi:
  - Certificati SSL validi e non in scadenza
  - Servizi up and healthy (docker compose ps, health status)
  - Nginx reverse proxy funzionante (curl test)
  - DNS resolution per dominio/sottodomini
  - Porte (80, 443) accessibili dall'esterno
- Log dei test in `logs/health-checks.log`

### 6. Documentazione Unificata
**Domande**:
- Creare README unificato per il nuovo sistema?
- File di troubleshooting comune per errori tipici?
- Documentazione della procedura di replicazione su altri server?

**Proposta**:
- `INSTALLATION.md` unico che:
  - Spiega prerequisiti (OS, DNS records, porte aperte)
  - Step-by-step del processo automatico
  - Output atteso vs errori comuni
  - Come usare il sistema su server multipli
- `TROUBLESHOOTING.md` con soluzioni per:
  - Errori Certbot (DNS validation, domain already exists)
  - Errori Docker (port already in use, volume mount issues)
  - Errori Nginx (config syntax, reverse proxy issues)
  - Errori Chatwoot (database connection, sidekiq workers)

### 7. Configurazioni Specifiche per Componenti

**Per Chatwoot**:
- `SECRET_KEY_BASE` generata e salvata in `.env.master`
- Redis/PostgreSQL containerizzati ma rilevabili (usa esistenti se trovati)
- Email SMTP configurabile (Gmail, SendGrid, Postfix locale)
- Storage configurabile (locale, S3, Azure)

**Per Portainer** (opzionale):
- Accesso web per management centralizzato
- Configurazione per conectarsi a servizi locali

**Per GLPI** (opzionale):
- Migrare da setup CLI a docker-compose?
- Database MariaDB containerizzato
- Plugin installation support

**Per Nginx** (base):
- Configurazione automatica per tutti i sottodomini
- SSL termination centralizzato
- Rate limiting se necessario

**Per Certbot** (automatico):
- Auto-renewal via systemd timer o cron
- Hook per reload Nginx post-renewal
- Certificati wildcard se dominio principale è valido

**Per Progetti Personalizzati** (custom):
- Rilevamento automatico requisiti da `docker-compose.yml`
- Mapping porta → sottodominio automatico
- Variabili ambiente iniettate da `.env.master`
- Health check custom (se definito nel progetto)
- Build automatica se presente `Dockerfile`

## Architecture Diagram

```
┌─ install.sh (Master Orchestrator)
│
├─ detect.sh
│  └─ Output: system-state.json
│
├─ interactive-setup.sh
│  ├─ Input: User dialogs (projects, domains, components)
│  └─ Output: setup-config.json
│
├─ download-projects.sh [NEW]
│  ├─ Input: setup-config.json (Git URLs)
│  ├─ Git clone custom projects
│  ├─ Scan dependencies (postgres, redis, etc.)
│  └─ Output: Projects in /opt/projects/<name> + dependencies map
│
├─ dependencies-manager.sh [NEW]
│  ├─ Input: Dependencies map from all projects
│  ├─ Ask user: shared vs dedicated containers
│  ├─ Generate docker-compose.dependencies.yml
│  └─ Output: Dependency strategy + init scripts
│
├─ ssl-setup.sh
│  ├─ Input: setup-config.json (ALL subdomains)
│  ├─ Certbot (Letsencrypt) for each subdomain
│  └─ Output: /etc/letsencrypt/live/*
│
├─ nginx-setup.sh [UPDATED]
│  ├─ Input: setup-config.json + SSL certs + projects
│  ├─ Generate reverse proxy config for EACH project
│  └─ Output: /etc/nginx/conf.d/<project>-*.conf (centralized)
│
├─ generate-env-master.sh
│  ├─ Input: setup-config.json + system-state.json + dependencies
│  └─ Output: .env.master (includes custom projects)
│
├─ docker-compose.yml (Global) + docker-compose.dependencies.yml
│  ├─ Input: .env.master
│  ├─ Services: Shared PostgreSQL, Redis, Nginx, Portainer
│  ├─ + Chatwoot (Rails, Sidekiq)
│  ├─ + Custom projects (via extends or separate compose)
│  └─ Output: All containers running on shared network
│
└─ health-check.sh
   ├─ Test SSL, DNS, Services, Ports for ALL projects
   └─ Output: health-check.log + summary
```

## File Structure (Proposed)

```
.
├── install.sh                      # Master orchestrator (Linux only)
├── docker-compose.yml              # Global compose file
├── docker-compose.dependencies.yml # Generated: shared dependencies
├── .env.master                     # Generated: centralized config (GITIGNORE)
├── .installation-state.json        # Generated: installation state (GITIGNORE)
│
├── scripts/
│   ├── detect.sh                   # System detection
│   ├── interactive-setup.sh        # User dialogs (with custom projects)
│   ├── download-projects.sh        # [NEW] Clone Git repos
│   ├── dependencies-manager.sh     # [NEW] Shared vs dedicated strategy
│   ├── ssl-setup.sh                # Certbot + Nginx config (all subdomains)
│   ├── nginx-setup.sh              # Centralized reverse proxy (all projects)
│   ├── generate-env-master.sh      # .env.master generator
│   ├── health-check.sh             # Post-deploy validation (all projects)
│   ├── backup.sh                   # Backup automation
│   └── restore.sh                  # Recovery from backup
│
├── templates/
│   ├── .env.master.template        # Template for .env.master
│   ├── nginx.conf.template         # Nginx config template
│   ├── docker-compose.template.yml # Compose template (if dynamic)
│   └── setup-config.schema.json    # JSON schema for setup-config.json
│
├── docs/
│   ├── INSTALLATION.md             # Step-by-step guide
│   ├── TROUBLESHOOTING.md          # Common issues + solutions
│   ├── REPLICATION.md              # Multi-server deployment
│   └── ARCHITECTURE.md             # Technical design docs
│
├── projects/                       # Generated: custom projects (GITIGNORE)
│   ├── <project-name>/
│   │   ├── docker-compose.yml      # Project's original compose
│   │   ├── .env                    # Generated from .env.master
│   │   └── ... (project files)
│   └── ...
│
└── logs/                           # Generated logs (GITIGNORE)
    ├── install-*.log
    ├── health-checks.log
    └── docker-compose.log
```

## Priority & Timeline Estimate

| # | Task | Complexity | Est. Time | Priority |
|---|------|-----------|-----------|----------|
| 1 | `detect.sh` | Medium | 1-2h | HIGH |
| 2 | `interactive-setup.sh` (with custom projects) | Medium-High | 3-4h | HIGH |
| 3 | `download-projects.sh` [NEW] | Medium | 2-3h | HIGH |
| 4 | `dependencies-manager.sh` [NEW] | High | 3-4h | HIGH |
| 5 | `ssl-setup.sh` (all subdomains) | Medium | 2h | HIGH |
| 6 | `nginx-setup.sh` (centralized multi-project) | High | 3-4h | HIGH |
| 7 | `generate-env-master.sh` + docker-compose | Medium | 2-3h | HIGH |
| 8 | `install.sh` master orchestrator | Medium | 2h | HIGH |
| 9 | `health-check.sh` + `backup.sh`/`restore.sh` | Medium | 2-3h | MEDIUM |
| 10 | Documentation (INSTALLATION, TROUBLESHOOTING, etc.) | Medium | 3-4h | MEDIUM |
| 11 | Testing on multiple Linux distributions | High | 3-4h | MEDIUM |

**Estimated Total**: 25-35h of development

## Success Criteria

- [ ] One command (`./install.sh`) sets up entire stack interactively
- [ ] System automatically detects existing services and asks about reuse
- [ ] **Support for custom Git projects** (public/private SSH repos) ✅ confermato
- [ ] **Intelligent dependency management** (shared vs dedicated PostgreSQL/Redis) - sempre chiede all'utente ✅
- [ ] **Centralized Nginx via nginx-proxy** for automatic reverse proxy ✅ nuovo
- [ ] **SSL certificates automated via acme-companion** (zero config Certbot) ✅ nuovo
- [ ] **Docker Compose Only strategy** - ignora script custom pericolosi ✅ nuovo
- [ ] Automatic conflict resolution (port remapping, volume renaming) ✅ nuovo
- [ ] All environment variables centralized in `.env.master` (including custom projects)
- [ ] Auto-inject `VIRTUAL_HOST` and `LETSENCRYPT_HOST` to all containers
- [ ] Script is idempotent and can be re-run safely
- [ ] Works identically on different Linux distributions (Ubuntu, CentOS, Debian)
- [ ] Can be replicated across multiple servers with same config
- [ ] Health checks verify all services working correctly (all projects)
- [ ] Complete documentation and troubleshooting guide included

## Questions for User (ANSWERED)

1. **Priorità**: ✅ **Core installer prima**, poi progetti custom (confermato)
   - Fase 1: Installer base con Chatwoot, Nginx, SSL, dipendenze
   - Fase 2: Sistema download progetti custom
   
2. **OS Support**: ✅ **Solo Linux** (confermato) - niente Windows/macOS

3. **Componenti Core**: Quali servizi vuoi nella v1?
   - ✅ Chatwoot (fisso)
   - Portainer? (gestione Docker web) - ❓ Da decidere
   - GLPI? (helpdesk/asset management) - ❓ Da decidere
   - Altri predefiniti? - ❓ Da decidere

4. **Progetti Personalizzati**:
   - ✅ **Supportare anche private repos con SSH keys** (confermato)
   - Dove salvare progetti: `/opt/projects/` o altra cartella? - ❓ Da decidere
   - Parsing automatico dipendenze o chiesta manuale? - ❓ Da decidere

5. **Dipendenze Condivise**:
   - ✅ **Chiedere SEMPRE all'utente** (confermato)
   - Proporre default intelligente ma permettere scelta manuale
   - Supportare versioni multiple di PostgreSQL (container dedicati)? - ✅ Sì

6. **Nginx Centralizzato**:
   - ✅ Un Nginx per tutti i progetti (confermato)
   - Rate limiting default? WAF (ModSecurity)? - ❓ Da decidere

7. **Backup**: Quanto importante il backup automatico? Criptare `.env.master`? - ❓ Da decidere

8. **Testing**: Test manuale o script di test automatici? - ❓ Da decidere
