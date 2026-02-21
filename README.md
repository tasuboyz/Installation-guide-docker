# 🐳 Installation Guide Docker

Documentazione per l'installazione e configurazione di un ecosistema containerizzato con n8n, Chatwoot, GLPI e reverse proxy SSL.

## 🚀 Quick Start

**Vuoi installare tutto rapidamente?** Segui la [**Guida Rapida**](QUICK-START.md) per deployment completo con SSL in 30 minuti.

## 📁 Struttura Repository

```
├── core-ecosystem/          # Infrastruttura principale
├── applications/            # Applicazioni opzionali
├── workflows/               # Workflow n8n e integrazioni
├── glpi-plugins/            # Plugin GLPI
└── reference/               # Documenti di riferimento
```

---

## 🏗️ Core Ecosystem

Guide per l'installazione dell'infrastruttura principale (seguire l'ordine numerico):

| # | Guida | Descrizione |
|---|-------|-------------|
| 1 | [Docker & Portainer](core-ecosystem/01-docker-portainer.md) | Installazione Docker e Portainer |
| 2 | [Rete Docker](core-ecosystem/02-docker-network.md) | Creazione della rete condivisa `glpi-net` |
| 3 | [GLPI](core-ecosystem/03-glpi-installation.md) | Sistema di gestione IT con MariaDB |
| 4 | [n8n](core-ecosystem/04-n8n-installation.md) | Piattaforma di automazione con PostgreSQL |
| 5 | [Nginx Proxy + SSL](core-ecosystem/05-nginx-certbot-ssl.md) | ⭐ **Reverse proxy con certificati SSL automatici** |

---

## 📦 Applicazioni

Applicazioni aggiuntive (installazione opzionale):

| Applicazione | Descrizione | Integrazione |
|--------------|-------------|--------------|
| [Chatwoot](applications/chatwoot/README.md) | Piattaforma di supporto clienti | ✅ n8n, SSL |
| [Nginx Proxy](applications/nginx-proxy/README.md) | ⭐ **Reverse proxy + Certbot SSL** | ✅ Tutti i servizi |
| [EspoCRM](applications/espocrm/README.md) | Sistema CRM | - |
| [Grafana](applications/grafana/README.md) | Dashboard e monitoraggio | ✅ Metriche servizi |
| [OpenClaw AI](applications/openclaw/README.md) | Gateway AI con sandboxing e canali | ✅ Telegram, Discord, WhatsApp |
| [Telegram Bot API](applications/telegram-bot-api/README.md) | Server Telegram Bot API personalizzato | ✅ n8n, Chatwoot |

---

## 📚 Riferimenti

Documenti di consultazione rapida:

- [Accesso ai servizi](reference/servizi-accesso.md) - URL e porte dei servizi
- [Comandi utili](reference/comandi-utili.md) - Comandi Docker frequenti
- [Sicurezza](reference/sicurezza.md) - Note di sicurezza
- [Dati persistenti](reference/dati-persistenti.md) - Gestione volumi Docker
- [Riferimenti esterni](reference/riferimenti.md) - Link utili

---

## ⚙️ Workflow n8n e Integrazioni

Workflow di automazione e guide integrazione:

| Workflow | Tipo | Descrizione |
|----------|------|-------------|
| [Guida Integrazione Completa](workflows/README.md) | 📖 Documentazione | ⭐ **Guida completa n8n ↔ Chatwoot con webhook** |
| `chatwoot-message-handler.json` | Chatwoot → n8n | Gestione automatica messaggi, notifiche, DB |
| `n8n-to-chatwoot-messages.json` | n8n → Chatwoot | Follow-up automatici, invio messaggi via API |
| `log_associazioni.json` | GLPI | Automazione log assegnazioni GLPI |
| `mail_associazioni.json` | GLPI | Automazione email notifiche GLPI |

**Highlights:**
- ✅ Webhook Chatwoot → n8n per eventi real-time
- ✅ API n8n → Chatwoot per messaggi automatici
- ✅ Persistenza database per analytics
- ✅ Risposte automatiche intelligenti
- ✅ Integrazione GLPI per ticket automatici

---

## 🔌 Plugin GLPI

Plugin personalizzati per GLPI:

- [Inventory Assignments](glpi-plugins/inventoryassignments/README.md) - Gestione assegnazioni inventario
- [AI Chat Assistant](glpi-plugins/aichatassistant/CONFRONTO_PLUGIN.md) - Assistente AI per GLPI
