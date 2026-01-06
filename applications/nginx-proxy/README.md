# Nginx Reverse Proxy + SSL Automatico

Setup COMPLETAMENTE AUTOMATIZZATO di nginx-proxy con certificati SSL Let's Encrypt.

## Quick Start

```bash
chmod +x install.sh add-service.sh
sudo ./install.sh
```

## Wizard Interattivo

Il sistema include un wizard che scansiona automaticamente tutti i container, mostra le porte e ti permette di assegnare sottodomini in modo rapido.

### Configurazione Singola

```bash
sudo ./add-service.sh
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SCANSIONE CONTAINER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌─────┬──────────────────────────────┬────────────────┬─────────────────┐
│  #  │ Container                    │ Immagine       │ Porte           │
├─────┼──────────────────────────────┼────────────────┼─────────────────┤
│   1 │ n8n                          │ n8n            │ 5678            │
│   2 │ chatwoot_rails               │ chatwoot       │ 3000            │
│   3 │ portainer                    │ portainer      │ 9443            │
│   4 │ grafana                      │ grafana        │ 3000            │
└─────┴──────────────────────────────┴────────────────┴─────────────────┘

Seleziona container [1-4]: 1
Porta auto-selezionata: 5678
[✓] Selezionato: n8n (porta 5678)

Sottodominio: n8n.miodominio.com

Procedo con la configurazione? [Y/n]: y

Configurazione in corso...
[✓] Configurazione completata!

https://n8n.miodominio.com

Configurare un altro servizio? [Y/n]: y
```

### Configurazione Batch (Più Servizi)

```bash
sudo ./add-service.sh --batch --base example.com
```

Output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CONFIGURAZIONE BATCH
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Dominio base (es: example.com): miodominio.com

┌─────┬──────────────────────────────┬────────────────┬─────────────────┐
│  #  │ Container                    │ Immagine       │ Porte           │
├─────┼──────────────────────────────┼────────────────┼─────────────────┤
│   1 │ n8n                          │ n8n            │ 5678            │
│   2 │ chatwoot_rails               │ chatwoot       │ 3000            │
│   3 │ portainer                    │ portainer      │ 9443            │
└─────┴──────────────────────────────┴────────────────┴─────────────────┘

Container da configurare: 1 2 3

Container: n8n (porta: 5678)
Sottodominio [n8n.miodominio.com]: ↵

Container: chatwoot_rails (porta: 3000)
Sottodominio [chatwoot-rails.miodominio.com]: chat.miodominio.com

Container: portainer (porta: 9443)
Sottodominio [portainer.miodominio.com]: ↵

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RIEPILOGO CONFIGURAZIONE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────────────────┬────────────────────────────────┬───────┐
│ Container                    │ Sottodominio                   │ Porta │
├──────────────────────────────┼────────────────────────────────┼───────┤
│ n8n                          │ n8n.miodominio.com             │  5678 │
│ chatwoot_rails               │ chat.miodominio.com            │  3000 │
│ portainer                    │ portainer.miodominio.com       │  9443 │
└──────────────────────────────┴────────────────────────────────┴───────┘

Procedere con la configurazione? [Y/n]: y

Applicazione configurazioni...

[✓] OK: https://n8n.miodominio.com
[✓] OK: https://chat.miodominio.com
[✓] OK: https://portainer.miodominio.com

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RIEPILOGO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Configurati: 3
```

## Automazione CLI

Per script e CI/CD:

```bash
# Setup proxy
sudo ./install.sh --network mynet --email admin@example.com --yes

# Aggiunta servizio
sudo ./add-service.sh -c n8n -d n8n.example.com -p 5678 -y

# Lista servizi
sudo ./add-service.sh --list
```

## Architettura

```
nginx-proxy/
├── install.sh              # Setup proxy
├── add-service.sh          # Wizard configurazione servizi
├── lib/
│   ├── common.sh           # Funzioni base
│   ├── docker_ops.sh       # Operazioni Docker
│   ├── ssl_config.sh       # Configurazione SSL
│   ├── vhost_manager.sh    # Gestione nginx vhost
│   ├── container_setup.sh  # Ricreazione container
│   └── prompts.sh          # UI interattiva e wizard
```

## Come Funziona

1. **Scansione automatica** - Rileva tutti i container Docker attivi
2. **Rilevamento porte** - Mostra le porte esposte da ogni container
3. **Suggerimento sottodominio** - Propone automaticamente `container.tuodominio.com`
4. **Configurazione automatica** - Ricrea il container con le variabili SSL necessarie
5. **Certificato automatico** - acme-companion richiede il certificato Let's Encrypt

## Servizi Speciali

Il wizard rileva automaticamente servizi che richiedono configurazione speciale:

- **Portainer (HTTPS backend)** - Proxy SSL automatico
- **WebSocket apps** - Headers upgrade configurati

## Staging vs Produzione

| Modalità | Certificati | Limite | Browser |
|----------|-------------|--------|---------|
| **Produzione** | Validi | 5/settimana per dominio | Fidati |
| **Staging** | Test | Illimitati | Non fidati |

## Monitoraggio

```bash
# Log certificati
docker logs -f nginx-proxy-acme

# Test HTTPS
curl -I https://n8n.miodominio.com

# Lista servizi configurati
sudo ./add-service.sh --list
```

## Troubleshooting

### Certificato non emesso

```bash
docker logs nginx-proxy-acme
dig +short n8n.miodominio.com
```

### Servizio non raggiungibile

```bash
docker logs nginx-proxy
docker exec nginx-proxy nginx -t
```

### Reset completo

```bash
docker compose down
docker volume rm nginx-certs nginx-vhost nginx-html acme-state
sudo ./install.sh
```

## Requisiti

- Docker e Docker Compose
- Porta 80 e 443 aperte
- DNS configurato
- Permessi root (sudo)
