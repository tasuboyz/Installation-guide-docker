# 📊 MAPPA VISUALE - Centralizzazione Domini

## 🗺️ DOVE TROVARE LE COSE

```
Retell-Backend/
│
├── docs/
│   ├── INDICE_CENTRALIZZAZIONE_DOMINI.md ⭐ INIZIA DA QUI
│   │   └─ Indice completo di tutti i documenti
│   │
│   ├── PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md ⭐ PASSO-PASSO
│   │   └─ Guida concreta: cosa fare e cosa scrivere
│   │
│   ├── CENTRALIZZAZIONE_DOMINI_GUIDE.md
│   │   └─ Guida completa: come funziona tutto
│   │
│   └── PHONE_ROUTING_CENTRALIZED.md
│       └─ Routing telefonico centralizzato
│
└── Installation-guide-docker/applications/nginx-proxy/
    ├── QUICK_START.md ⭐ 5 MIN SETUP
    │   └─ Quick reference card
    │
    ├── README.md
    │   └─ Documentazione ufficiale dello strumento
    │
    ├── CHEATSHEET.md
    │   └─ Comandi frequenti
    │
    ├── setup-domains.sh ⭐ SCRIPT PRINCIPALE
    │   └─ Esegui questo per setup automatico
    │
    ├── list-configured-urls.sh
    │   └─ Visualizza URL già configurati
    │
    ├── diagnose.sh
    │   └─ Diagnostica completa se ha problemi
    │
    └── install.sh
        └─ Setup manuale (avanzato)
```

---

## 🎯 PERCORSO DI LETTURA CONSIGLIATO

### Se Hai 5 Minuti
```
1. QUICK_START.md (nginx-proxy/)
   ↓
2. ./setup-domains.sh (esegui script)
   ↓
3. ./list-configured-urls.sh (verifica URL)
```

### Se Hai 15 Minuti
```
1. PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md (docs/)
   ↓
2. CENTRALIZZAZIONE_DOMINI_GUIDE.md (docs/)
   ↓
3. ./setup-domains.sh (esegui script)
```

### Se Vuoi Capire Tutto
```
1. INDICE_CENTRALIZZAZIONE_DOMINI.md (docs/)
   ↓
2. CENTRALIZZAZIONE_DOMINI_GUIDE.md (docs/)
   ↓
3. Installation-guide-docker/README.md
   ↓
4. PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md (docs/)
   ↓
5. ./setup-domains.sh (esegui script)
```

---

## 🚀 QUICK REFERENCE COMMANDS

### Setup
```bash
cd Installation-guide-docker/applications/nginx-proxy
chmod +x *.sh
sudo ./setup-domains.sh
```

### Recupera URL Salvati
```bash
./list-configured-urls.sh
```

### Diagnostica Problemi
```bash
./diagnose.sh
```

### Monitora Certificati
```bash
docker logs -f nginx-proxy-acme
```

### Testa URL
```bash
curl -I https://ai.tuodominio.com
curl -I https://portainer.tuodominio.com
```

---

## 📋 CHECKLIST SETUP

```
[ ] Ho letto PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md
[ ] Ho aperto WSL
[ ] Ho navigato in nginx-proxy/
[ ] Ho eseguito: chmod +x *.sh
[ ] Ho eseguito: sudo ./setup-domains.sh
[ ] Ho risposto: email, dominio, rete
[ ] Ho scelto: retell-backend
[ ] Ho inserito: ai.tuodominio.com
[ ] Ho confermato: Y
[ ] Ho aspettato: 1-2 minuti
[ ] Ho eseguito: ./list-configured-urls.sh
[ ] Ho visto: ✓ ai.tuodominio.com
[ ] Ho rieseguito: sudo ./setup-domains.sh
[ ] Ho scelto: portainer
[ ] Ho inserito: portainer.tuodominio.com
[ ] Ho confermato: Y
[ ] Ho aspettato: 1-2 minuti
[ ] Ho testato: https://ai.tuodominio.com nel browser
[ ] Ho testato: https://portainer.tuodominio.com nel browser
[ ] Ho salvato gli URL in backup
```

---

## 🔍 DOMANDE FREQUENTI

**Q: Dove sono i miei URL?**
```bash
./list-configured-urls.sh
```

**Q: Come cambio sottodominio?**
```bash
# Riesegui lo script e scegli "STAGING" per test
sudo ./setup-domains.sh
```

**Q: Certificato non viene generato?**
```bash
./diagnose.sh
# Controlla: DNS configurato? Email valida? Porte aperte?
```

**Q: Come rinnoviamo i certificati?**
```
Automatico! acme-companion lo fa 30 giorni prima della scadenza.
Nulla da fare manualmente.
```

**Q: Posso configurare altri servizi?**
```bash
sudo ./setup-domains.sh
# Riesegui per n8n, Chatwoot, ecc.
```

---

## 🎓 ARCHITETTURA AD ALTA LIVELLO

```
┌─────────────────────────────────────────┐
│        INTERNET (HTTPS)                 │
│  https://ai.tuodominio.com  ✓ SSL      │
│  https://portainer.tuo...   ✓ SSL      │
│  https://automation.tuo...  ✓ SSL      │
└────────────┬────────────────────────────┘
             │
             │ (Let's Encrypt Certificates)
             │
    ┌────────▼─────────┐
    │  NGINX-PROXY     │
    │  Port 443 (HTTPS)│
    │  + acme-friend   │
    └────────┬─────────┘
             │
   ┌─────────┼─────────┐
   │         │         │
   ▼         ▼         ▼
 AI:8080  Port:9443  n8n:5678

Docker Network: glpi-net
(tutti i container connessi)
```

---

## 📊 SERVIZI SUPPORTATI

| Servizio | Porta | Configurazione |
|----------|-------|----------------|
| **Retell Backend (AI)** | 8080 | `ai.tuodominio.com` |
| **Portainer** | 9443 | `portainer.tuodominio.com` |
| **n8n** | 5678 | `automation.tuodominio.com` |
| **Chatwoot** | 3000 | `chat.tuodominio.com` |
| **Grafana** | 3000 | `metrics.tuodominio.com` |
| **Qualsiasi servizio** | custom | `servizio.tuodominio.com` |

---

## ⚡ COMANDI GIORNALIERI

```bash
# Visualizza stato
docker ps | grep nginx-proxy
docker ps | grep retell-backend
docker ps | grep portainer

# Accedi a Retell Backend
curl -I https://ai.tuodominio.com

# Accedi a Portainer
# Browser: https://portainer.tuodominio.com

# Monitora certificati
docker logs -f nginx-proxy-acme

# Riavvia un servizio
docker restart retell-backend
docker restart portainer

# Salva URL in file
./list-configured-urls.sh > urls-backup.txt
```

---

## 📞 LINK RAPIDI

| Risorsa | Link |
|---------|------|
| **Guida Passo-Passo** | [PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md](../docs/PROCEDURA_RECUPERO_URL_RETELL_PORTAINER.md) |
| **Guida Completa** | [CENTRALIZZAZIONE_DOMINI_GUIDE.md](../docs/CENTRALIZZAZIONE_DOMINI_GUIDE.md) |
| **Quick Start** | [QUICK_START.md](QUICK_START.md) |
| **Indice Completo** | [INDICE_CENTRALIZZAZIONE_DOMINI.md](../docs/INDICE_CENTRALIZZAZIONE_DOMINI.md) |
| **Script Setup** | [setup-domains.sh](setup-domains.sh) |
| **Visualizza URL** | [list-configured-urls.sh](list-configured-urls.sh) |
| **Diagnostica** | [diagnose.sh](diagnose.sh) |

---

## 💡 TIPS AVANZATI

### Backup Certificati
```bash
docker cp nginx-proxy:/etc/nginx/certs ./backup-certs-$(date +%Y%m%d)
```

### Reload Nginx Dopo Config Change
```bash
docker exec nginx-proxy nginx -s reload
```

### Controlla VHOST Configurati
```bash
docker exec nginx-proxy cat /etc/nginx/vhost.d/ai.tuodominio.com
```

### Verifica Connettività Container
```bash
docker exec nginx-proxy ping retell-backend
docker exec nginx-proxy ping portainer
```

### Controlla Certificato Scadenza
```bash
docker exec nginx-proxy-acme openssl x509 -enddate -noout \
  -in /etc/nginx/certs/ai.tuodominio.com/fullchain.pem
```

---

## ✅ SUCCESSO!

Una volta completo il setup:
- ✅ URL centralizzate e facili da trovare
- ✅ Certificati SSL automatici
- ✅ Rinnovo automatico dei certificati
- ✅ HTTPS per tutti i servizi
- ✅ Zero manutenzione futura

🎉 **Done!**

