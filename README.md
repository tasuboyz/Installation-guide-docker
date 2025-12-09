# 🐳 Installation Guide Docker

Documentazione per l'installazione e configurazione di un ecosistema containerizzato.

## 📁 Struttura Repository

```
├── core-ecosystem/          # Infrastruttura principale
├── applications/            # Applicazioni opzionali
├── reference/               # Documenti di riferimento
├── workflows/               # Workflow n8n
└── glpi-plugins/            # Plugin GLPI
```

---

## 🏗️ Core Ecosystem

Guide per l'installazione dell'infrastruttura principale (seguire l'ordine numerico):

| # | Guida | Descrizione |
|---|-------|-------------|
| 1 | [Docker & Portainer](core-ecosystem/01-docker-portainer.md) | Installazione Docker e Portainer |
| 2 | [Rete Docker](core-ecosystem/02-docker-network.md) | Creazione della rete condivisa |
| 3 | [GLPI](core-ecosystem/03-glpi-installation.md) | Sistema di gestione IT con MariaDB |
| 4 | [n8n](core-ecosystem/04-n8n-installation.md) | Piattaforma di automazione con PostgreSQL |

---

## 📦 Applicazioni

Applicazioni aggiuntive (installazione opzionale):

| Applicazione | Descrizione |
|--------------|-------------|
| [Chatwoot](applications/chatwoot/README.md) | Piattaforma di supporto clienti |
| [EspoCRM](applications/espocrm/README.md) | Sistema CRM |
| [Grafana](applications/grafana/README.md) | Dashboard e monitoraggio |
| [Telegram Bot API](applications/telegram-bot-api/README.md) | Server Telegram Bot API personalizzato |

---

## 📚 Riferimenti

Documenti di consultazione rapida:

- [Accesso ai servizi](reference/servizi-accesso.md) - URL e porte dei servizi
- [Comandi utili](reference/comandi-utili.md) - Comandi Docker frequenti
- [Sicurezza](reference/sicurezza.md) - Note di sicurezza
- [Dati persistenti](reference/dati-persistenti.md) - Gestione volumi Docker
- [Riferimenti esterni](reference/riferimenti.md) - Link utili

---

## ⚙️ Workflow n8n

Workflow di automazione per n8n:

- `workflows/log_associazioni.json` - Automazione log GLPI
- `workflows/mail_associazioni.json` - Automazione email GLPI

---

## 🔌 Plugin GLPI

Plugin personalizzati per GLPI:

- [Inventory Assignments](glpi-plugins/inventoryassignments/README.md) - Gestione assegnazioni inventario
