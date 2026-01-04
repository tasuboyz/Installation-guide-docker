# 🚀 QUICK REFERENCE - Centralizzazione Domini Retell + Portainer

## In 5 Minuti: Configure i Tuoi Domini

### 1️⃣ Apri WSL (Windows)
```bash
wsl
cd /mnt/c/Users/d.kato/Documents/Retell-Backend/Installation-guide-docker/applications/nginx-proxy
chmod +x *.sh
sudo ./setup-domains.sh
```

### 2️⃣ Rispondi alle Domande
- **Email Let's Encrypt**: tua@email.com
- **Dominio principale**: tuodominio.com
- **Rete Docker**: glpi-net (default)

### 3️⃣ Lo Script Fa Tutto
- ✅ Avvia nginx-proxy + acme-companion
- ✅ Chiede quale servizio esporre (Retell, Portainer, n8n...)
- ✅ Chiede sottodominio (es: ai.tuodominio.com)
- ✅ Riconfigura il container con SSL automatico
- ✅ Genera certificati Let's Encrypt in 1-2 minuti

### 4️⃣ Verifica
```bash
# Controlla i certificati
docker logs -f nginx-proxy-acme

# Testa nel browser dopo 2 minuti
https://ai.tuodominio.com
https://portainer.tuodominio.com
```

---

## 📝 Configurazione Consigliata

| Servizio | Sottodominio | Porta | Comando Setup |
|----------|--------------|-------|---------------|
| **AI Voice Agent (Retell)** | `ai.tuodominio.com` | 8080 | `./setup-domains.sh` |
| **Portainer** | `portainer.tuodominio.com` | 9443 | `./setup-domains.sh` |
| **n8n** (opzionale) | `automation.tuodominio.com` | 5678 | `./setup-domains.sh` |
| **Chatwoot** (opzionale) | `chat.tuodominio.com` | 3000 | `./setup-domains.sh` |

---

## 🔍 Recupera URL Perduti

```bash
# Visualizza tutti i servizi configurati
./list-configured-urls.sh

# Visualizza env di un container specifico
docker inspect retell-backend | grep VIRTUAL_HOST

# Leggi il file di config salvato
cat .env.domains
cat configs/retell-backend.conf
cat configs/portainer.conf
```

---

## ⚠️ Prerequisiti Essenziali

- ✅ **DNS configurato** (sottodominio punta al tuo server IP)
- ✅ **Docker in esecuzione** (Docker Desktop)
- ✅ **Porte 80 e 443 aperte** (il proxy le usa)
- ✅ **Email valida** (per rinnovo automatico certificati)

---

## 🛠️ Troubleshooting Veloce

### ❌ Certificato non emesso dopo 5 min
```bash
# Controlla DNS
dig +short ai.tuodominio.com
# Dovrebbe mostrare il tuo IP server

# Controlla log errori
docker logs nginx-proxy-acme 2>&1 | tail -20
```

### ❌ "Connection refused"
```bash
# Verifica container nella rete
docker network inspect glpi-net

# Ping tra container
docker exec nginx-proxy ping retell-backend
```

### ❌ Browser dice "SSL non valido"
```bash
# Stai usando STAGING (certificati test)
# Riesegui e scegli PRODUZIONE (opzione 1)

sudo ./setup-domains.sh
# → Scegli: 1 (PRODUZIONE)
```

---

## 📊 Architettura

```
┌─ INTERNET (HTTPS) ─────────────────────────────────┐
│                                                      │
│  ai.tuodominio.com   ──SSL──→ Let's Encrypt ✓     │
│  portainer.tuodominio.com  ──SSL──→ Let's Encrypt ✓ │
└──────────────────────┬─────────────────────────────┘
                       │
             NGINX-PROXY (Port 443)
                       │
        ┌──────────┬───┴────┬──────────┐
        │          │        │          │
   Retell:8080  Port:9443  n8n:5678  Chat:3000
     (glpi-net)
```

---

## 💾 File Importanti

```
nginx-proxy/
├── install.sh                ← Script principale (automatico)
├── setup-domains.sh          ← Helper per setup rapido
├── list-configured-urls.sh   ← Leggi URL salvati
├── .env.domains              ← Config sottodomini (generato)
├── configs/                  ← Config per servizio (generato)
│   ├── retell-backend.conf
│   └── portainer.conf
└── vhost-configs/            ← Config nginx (generato)
```

---

## 🎯 Flusso Completo (Step-by-Step)

```bash
# 1. Naviga in directory
cd Installation-guide-docker/applications/nginx-proxy

# 2. Rendi eseguibili gli script
chmod +x *.sh

# 3. Avvia setup
sudo ./setup-domains.sh

# 4. Rispondi: email, dominio
# (es: admin@example.com, tuodominio.com)

# 5. Script avvia nginx-proxy e ti chiede:
#    - Quale container? (retell-backend, portainer, n8n, ecc.)
#    - Quale sottodominio? (ai.tuodominio.com)
#    - Conferma? (Y)

# 6. Lo script riconfigura il container + SSL
# (NO modifiche manuali richieste!)

# 7. Attendi 1-2 minuti
docker logs -f nginx-proxy-acme

# 8. Testa
curl -I https://ai.tuodominio.com
# → HTTP/2 200 = OK!

# 9. Riesegui per altri servizi
sudo ./setup-domains.sh
```

---

## 📞 Link Utili

- **Documentazione nginx-proxy**: https://github.com/nginxproxy/nginx-proxy
- **Let's Encrypt**: https://letsencrypt.org/
- **Test SSL**: https://www.ssllabs.com/ssltest/

---

## ✅ Checklist Finale

- [ ] DNS configurato (sottodominio punta a IP server)
- [ ] Docker in esecuzione
- [ ] Script eseguito con successo
- [ ] .env.domains generato
- [ ] Certificati emessi (controlla logs)
- [ ] URL accessibili nel browser
- [ ] Documenta gli URL per il team

**Una volta configurato, NON devi più toccarlo!** I certificati si rinnovano automaticamente.

