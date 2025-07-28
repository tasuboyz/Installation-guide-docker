# 📊 Inventory Assignments Plugin per GLPI

## 🎯 Descrizione

Il plugin **Inventory Assignments** aggiunge una nuova sezione al menu **Inventario** di GLPI che permette di visualizzare una tabella completa di tutte le assegnazioni utenti nel sistema.

## ✨ Caratteristiche

### 🎨 **Interface Moderna**
- Design Bootstrap 5 con tema verde inventario
- Tabelle responsive e interattive
- Icone Tabler Icons integrate
- Animazioni CSS fluide

### 📋 **Funzionalità Principali**
- **Tabella Assegnazioni**: Visualizza tutte le assegnazioni computer-utente
- **Statistiche**: Mostra computer non assegnati e utenti con più dispositivi
- **Link Diretti**: Collegamenti rapidi a computer e utenti
- **Filtri Integrati**: Ordinamento e ricerca native

### 📊 **Informazioni Visualizzate**
- Nome computer (con link diretto)
- Numero seriale dispositivo
- Utente assegnato (con link al profilo)
- Ubicazione (location)
- Stato corrente
- Data ultimo aggiornamento
- Azioni rapide (visualizza computer/utente)

## 🚀 Installazione

### Requisiti
- GLPI 10.0.0 o superiore
- Permessi di accesso alla configurazione

### Procedura
1. Copia la cartella `inventoryassignments` in `/plugins/`
2. Vai in **Configurazione > Plugin**
3. Clicca su **Installa** accanto a "Inventory Assignments"
4. Clicca su **Attiva** per abilitare il plugin

## 🎮 Utilizzo

### Accesso al Plugin
1. Vai nella sezione **Inventario** (Assets)
2. Clicca su **Assegnazioni Utenti** nel menu
3. Visualizza la tabella completa delle assegnazioni

### Interpretazione dei Dati

#### 📋 Tabella Principale
```
Computer        | Serial    | Utente Assegnato  | Ubicazione | Stato      | Ultimo Agg.
PC-001         | SN123456  | Mario Rossi       | Sede Roma  | In uso     | 15/01/2025
LAPTOP-042     | LT789012  | Anna Verdi        | Filiale MI | Riparazione| 10/01/2025
```

#### 📊 Statistiche
- **Computer Non Assegnati**: Dispositivi senza utente
- **Utenti Multi-Computer**: Utenti con più di un dispositivo

## 🔧 Caratteristiche Tecniche

### Architettura
```
plugins/inventoryassignments/
├── setup.php                 # Configurazione plugin
├── inc/
│   └── assignment.class.php   # Classe principale
├── front/
│   └── assignment.php         # Pagina frontend
├── css/
│   └── inventoryassignments.css # Stili personalizzati
└── README.md                  # Documentazione
```

### Database
Il plugin **NON** crea tabelle aggiuntive, ma utilizza:
- `glpi_computers` (dispositivi)
- `glpi_users` (utenti)
- `glpi_locations` (ubicazioni)
- `glpi_states` (stati)

### Query Ottimizzate
```sql
-- Query principale per assegnazioni
SELECT 
    c.id, c.name, c.serial,
    u.id, u.name, CONCAT(u.firstname, ' ', u.realname) as fullname,
    l.completename as location,
    s.name as state,
    c.date_mod
FROM glpi_computers c
LEFT JOIN glpi_users u ON c.users_id = u.id
LEFT JOIN glpi_locations l ON c.locations_id = l.id
LEFT JOIN glpi_states s ON c.states_id = s.id
WHERE c.users_id > 0 AND c.is_deleted = 0
ORDER BY fullname, c.name
```

## 🎨 Personalizzazione

### Colori Tema
```css
/* Tema verde inventario */
--primary-color: #28a745
--secondary-color: #20c997
--warning-color: #ffc107
--info-color: #17a2b8
```

### Responsive Design
- **Desktop**: Tabella completa
- **Tablet**: Tabella ottimizzata
- **Mobile**: Layout adattivo

## 🔐 Permessi

Il plugin rispetta i permessi GLPI:
- **Lettura**: Permesso `config` READ
- **Modifica**: Permesso `config` UPDATE

## ⚡ Performance

### Ottimizzazioni
- Query con `LEFT JOIN` ottimizzate
- Indici database nativi GLPI
- CSS minificato
- Caricamento asincrono risorse

### Limits
- Nessun limite di records (dipende da GLPI)
- Paginazione nativa browser
- Cache query secondo configurazione GLPI

## 🔄 Integrazione

### Menu GLPI
```php
$PLUGIN_HOOKS['menu_toadd']['inventoryassignments'] = [
    'assets' => 'PluginInventoryassignmentsAssignment'
];
```

### Hook Supportati
- `csrf_compliant` - Protezione CSRF
- `add_css` - Caricamento CSS
- `menu_toadd` - Aggiunta menu

## 🐛 Risoluzione Problemi

### Plugin Non Visibile
1. Verificare installazione in `/plugins/inventoryassignments/`
2. Controllare permessi cartelle (755)
3. Verificare attivazione in **Configurazione > Plugin**

### Errori Database
1. Verificare connessione database GLPI
2. Controllare permessi utente database
3. Verificare integrità tabelle GLPI

### Problemi CSS
1. Svuotare cache browser
2. Verificare caricamento file CSS
3. Controllare console browser per errori

## 📝 Log e Debug

### Abilitare Debug
```php
// In setup.php
if (isset($_SESSION['glpiID'])) {
    error_log('InventoryAssignments: Plugin inizializzato per utente ' . $_SESSION['glpiID']);
}
```

### Log Posizioni
- GLPI logs: `/files/_log/`
- Server logs: secondo configurazione server
- Browser console: F12 > Console

## 🔄 Aggiornamenti

### Versione 1.0.0
- ✅ Tabella assegnazioni complete
- ✅ Statistiche computer non assegnati
- ✅ Design responsive moderno
- ✅ Link diretti a computer/utenti
- ✅ Integrazione menu Inventario

### Roadmap Future
- 🔄 Esportazione dati (CSV/PDF)
- 🔄 Filtri avanzati
- 🔄 Grafici statistiche
- 🔄 Notifiche scadenze
- 🔄 API REST integration

## 💡 Casi d'Uso

### Amministratori IT
```
Scenario: Controllo inventario mensile
1. Accedi a Inventario > Assegnazioni Utenti
2. Visualizza tabella completa assegnazioni
3. Identifica computer non assegnati
4. Verifica utenti con più dispositivi
5. Aggiorna assegnazioni se necessario
```

### Help Desk
```
Scenario: Richiesta supporto utente
1. Utente chiama per problema PC
2. Cerca utente in tabella assegnazioni
3. Identifica computer assegnato
4. Clicca link diretto a computer
5. Visualizza dettagli e storia
```

### Inventory Manager
```
Scenario: Report direzionale
1. Accedi a statistiche plugin
2. Controlla computer non assegnati
3. Identifica sprechi risorse
4. Prepara report ottimizzazione
```

## 🤝 Supporto

### Community
- GLPI Community Forum
- GitHub Issues
- GLPI Plugin Directory

### Sviluppo
- Basato su framework GLPI 10+
- Compatible con plugin ecosystem
- Segue best practice GLPI

---

## 📜 Licenza

GPL v2+ - Compatible con licenza GLPI

## 👨‍💻 Autore

GLPI Developer - Plugin Inventory Assignments

---

**🚀 Plugin pronto per l'uso in ambiente di produzione!**
