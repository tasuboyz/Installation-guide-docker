# 🚀 INSTALLAZIONE PLUGIN INVENTORY ASSIGNMENTS

## ⚡ Installazione Rapida

### 1. Copia Files
```bash
# Copia la cartella del plugin
cp -r inventoryassignments/ /path/to/glpi/plugins/
```

### 2. Imposta Permessi
```bash
# Imposta permessi corretti
chmod -R 755 /path/to/glpi/plugins/inventoryassignments/
chown -R www-data:www-data /path/to/glpi/plugins/inventoryassignments/
```

### 3. Attiva Plugin
1. Vai in **Configurazione > Plugin**
2. Trova "Inventory Assignments"
3. Clicca **Installa**
4. Clicca **Attiva**

### 4. Verifica Installazione
1. Vai in **Inventario** (Assets)
2. Verifica presenza menu **Assegnazioni Utenti**
3. Clicca e verifica funzionamento tabella

## ✅ Test di Funzionamento

### Test Base
- [ ] Menu visibile in sezione Inventario
- [ ] Pagina si carica senza errori
- [ ] Tabella mostra assegnazioni esistenti
- [ ] Link a computer/utenti funzionano
- [ ] Statistiche si caricano correttamente

### Test Permessi
- [ ] Admin vede tutto
- [ ] Utenti con permessi config vedono menu
- [ ] Utenti senza permessi non vedono menu

### Test Responsive
- [ ] Desktop: layout completo
- [ ] Tablet: tabella responsive
- [ ] Mobile: layout adattivo

## 🔧 Configurazione Avanzata

### Personalizzazione CSS
Modifica `/plugins/inventoryassignments/css/inventoryassignments.css`

### Personalizzazione Query
Modifica `/plugins/inventoryassignments/inc/assignment.class.php`

### Debug Mode
Decommenta le righe di log in `setup.php`

## 🆘 Risoluzione Problemi

### Plugin Non Compare
```bash
# Verifica files
ls -la /path/to/glpi/plugins/inventoryassignments/

# Verifica permessi
ls -la /path/to/glpi/plugins/ | grep inventoryassignments

# Verifica log GLPI
tail -f /path/to/glpi/files/_log/glpi.log
```

### Errori Database
1. Verifica connessione GLPI
2. Controlla permessi utente database
3. Verifica queries in console browser

### CSS Non Caricato
1. Svuota cache browser
2. Verifica path CSS nel codice
3. Controlla errori console browser

---

**Plugin installato con successo! 🎉**
