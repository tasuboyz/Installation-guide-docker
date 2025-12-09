# Installazione GLPI con Docker

## Panoramica
GLPI (Gestionnaire Libre de Parc Informatique) è un sistema di gestione IT e ticketing open source. Questa guida mostra come installarlo usando Docker con MariaDB come database.

## Prerequisiti
- Docker e Docker Compose installati
- Rete Docker condivisa (`glpi-net`)

## 1. Creazione della rete Docker
```bash
docker network create glpi-net
```

## 2. Installazione e avvio del database MariaDB
```bash
docker run --name mariadb \
  --network glpi-net \
  -e MARIADB_ROOT_PASSWORD='G!lpiRoot2025$#' \
  -e MARIADB_DATABASE=glpidb \
  -e MARIADB_USER=glpi \
  -e MARIADB_PASSWORD=GlpiUser!2025$# \
  -e TZ=Europe/Rome \
  -v /etc/localtime:/etc/localtime:ro \
  -v mariadb-data:/var/lib/mysql \
  -d mariadb:10.7
```

## 3. Creazione del volume dati per GLPI
```bash
docker create --name glpi-data \
  -v /var/www/html/glpi \
  diouxx/glpi /bin/true
```

## 4. Avvio del container GLPI
```bash
docker run --name glpi \
  --network glpi-net \
  --volumes-from glpi-data \
  -p 81:80 \
  -e TIMEZONE=Europe/Rome \
  -d diouxx/glpi
```

## 5. Accesso al servizio
- GLPI: `http://<IP_SERVER>:81`

## 6. Configurazione iniziale
Dopo l'avvio, accedi all'interfaccia web per completare la configurazione iniziale di GLPI.

### Parametri di connessione database:
- Host: `mariadb`
- Database: `glpidb`
- User: `glpi`
- Password: `GlpiUser!2025$#`

## 7. Gestione dei dati persistenti
- Dati di GLPI: volume `glpi-data`
- Dati del database MariaDB: volume `mariadb-data`

## 8. Comandi utili
```bash
# Fermare i servizi
docker stop glpi mariadb

# Avviare i servizi
docker start mariadb glpi

# Vedere i log
docker logs glpi
docker logs mariadb

# Backup del database
docker exec mariadb mysqldump -u root -p'G!lpiRoot2025$#' glpidb > glpi_backup.sql

# Ripristino del database
docker exec -i mariadb mysql -u root -p'G!lpiRoot2025$#' glpidb < glpi_backup.sql
```

## 9. Configurazioni aggiuntive

### Configurazione Email
Per configurare l'invio di email in GLPI, accedi a:
Configurazione → Notifiche → Configurazione Email

### Configurazione LDAP
Per integrare GLPI con Active Directory/LDAP:
Configurazione → Autenticazione → LDAP

### Deployment Agent GLPI tramite GPO
Per automatizzare l'installazione dell'agent GLPI sui client tramite Group Policy Objects (GPO) o strumenti di deploy:

#### Script di installazione automatica
Creare un file batch (es. `install_glpi_agent.bat`) con il seguente contenuto:

```batch
@echo off

REM Verifica e crea la cartella C:\Temp se non esiste
IF EXIST "C:\Temp" (
    echo "C:\Temp folder exists."
) ELSE (
    echo "C:\Temp folder does not exist. Creating folder..."
    mkdir "C:\Temp"
)

REM Verifica se GLPI Agent è già installato
IF EXIST "C:\Program Files\GLPI-Agent" (
    echo "GLPI Agent already installed. No action needed."
) ELSE (
    echo "GLPI Agent not found. Installing..."
    
    REM Installazione silenziosa dell'agent GLPI
    \\172.30.0.118\GLPI-Agent\GLPI-Agent-1.15-x64.msi /quiet /norestart /l*V "C:\Temp\GLPI-Agent-Install.log" SERVER="http://172.30.0.48"
    
    REM Verifica se l'installazione è riuscita
    IF %ERRORLEVEL% EQU 0 (
        echo "GLPI Agent installed successfully."
    ) ELSE (
        echo "GLPI Agent installation failed. Check log file: C:\Temp\GLPI-Agent-Install.log"
    )
)

echo "Script completed."
```

#### Configurazione tramite GPO (Group Policy Objects)

1. **Apertura Group Policy Management Console (GPMC)**
   - Apri `gpmc.msc` sul Domain Controller
   - Naviga alla OU desiderata

2. **Creazione nuova GPO**
   - Crea una nuova GPO: "GLPI Agent Deployment"
   - Modifica la GPO

3. **Configurazione Script di Startup**
   - Vai a: `Computer Configuration → Policies → Windows Settings → Scripts (Startup/Shutdown)`
   - Doppio click su "Startup"
   - Aggiungi il file `install_glpi_agent.bat`

4. **Configurazione Script di Logon (alternativa)**
   - Vai a: `User Configuration → Policies → Windows Settings → Scripts (Logon/Logoff)`
   - Doppio click su "Logon"
   - Aggiungi il file `install_glpi_agent.bat`

#### Deployment tramite SCCM/MECM

```powershell
# Script PowerShell per SCCM
$AgentPath = "\\172.30.0.118\GLPI-Agent\GLPI-Agent-1.15-x64.msi"
$LogPath = "C:\Temp\GLPI-Agent-Install.log"
$ServerURL = "http://172.30.0.48"

# Verifica se l'agent è già installato
if (!(Test-Path "C:\Program Files\GLPI-Agent")) {
    # Installazione silenziosa
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$AgentPath`" /quiet /norestart /l*V `"$LogPath`" SERVER=`"$ServerURL`"" -Wait
    
    # Verifica installazione
    if (Test-Path "C:\Program Files\GLPI-Agent") {
        Write-Host "GLPI Agent installed successfully"
        exit 0
    } else {
        Write-Host "GLPI Agent installation failed"
        exit 1
    }
} else {
    Write-Host "GLPI Agent already installed"
    exit 0
}
```

#### Parametri di installazione MSI

- `/quiet` - Installazione silenziosa senza interfaccia utente
- `/norestart` - Impedisce il riavvio automatico del sistema
- `/l*V "percorso_log"` - Crea un log dettagliato dell'installazione
- `SERVER="http://IP_GLPI"` - Specifica l'URL del server GLPI

#### Note per il deployment
- Assicurarsi che il file MSI sia accessibile da tutti i client
- Testare lo script su un gruppo limitato prima del rollout completo
- Verificare i permessi di accesso alla condivisione di rete
- Monitorare i log di installazione per eventuali errori

## 10. Note di sicurezza
- **Cambia le password di default** dopo l'installazione
- Esponi le porte solo su reti sicure
- Esegui backup regolari dei volumi
- Considera l'uso di HTTPS in produzione

## 11. Troubleshooting

### Container non si avvia
```bash
# Controlla i log
docker logs glpi
docker logs mariadb

# Verifica la rete
docker network ls
docker network inspect glpi-net
```

### Database non raggiungibile
```bash
# Testa la connessione al database
docker exec -it mariadb mysql -u glpi -p'GlpiUser!2025$#' glpidb
```

### Problemi di permessi
```bash
# Controlla i permessi del volume
docker exec -it glpi ls -la /var/www/html/glpi
```

## 12. Riferimenti
- [GLPI Docker diouxx](https://hub.docker.com/r/diouxx/glpi)
- [MariaDB Docker](https://hub.docker.com/_/mariadb)
- [Documentazione ufficiale GLPI](https://glpi-project.org/)
- [GLPI User Documentation](https://glpi-project.org/documentation/)
