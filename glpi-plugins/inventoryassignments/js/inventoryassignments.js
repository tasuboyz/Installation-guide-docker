/**
 * JavaScript per il plugin Inventory Assignments
 */

document.addEventListener('DOMContentLoaded', function() {
    
    // Aggiungi funzionalità di ricerca nella tabella
    addTableSearch();
    
    // Aggiungi contatori dinamici
    updateCounters();
    
    // Aggiungi export capabilities (se richiesto)
    addExportButton();
    
    // Gestisci click sui bottoni storico
    document.querySelectorAll('.show-history').forEach(button => {
        button.addEventListener('click', function() {
            const computerId = this.dataset.computerId;
            const row = this.closest('tr');
            
            // Rimuovi eventuali righe di storico aperte
            document.querySelectorAll('.history-row').forEach(el => el.remove());
            
            // Se c'era già una riga aperta per questo computer, la chiudiamo
            if (row.nextElementSibling && row.nextElementSibling.classList.contains('history-row')) {
                row.nextElementSibling.remove();
                return;
            }
            
            // Creiamo la nuova riga per lo storico
            const historyRow = document.createElement('tr');
            historyRow.classList.add('history-row', 'table-light');
            
            // Colonna che occupa tutta la larghezza
            const historyCell = document.createElement('td');
            historyCell.setAttribute('colspan', '7');
            historyCell.innerHTML = '<div class="p-3 loading"><i class="ti ti-loader animate-spin me-2"></i>Caricamento storico...</div>';
            historyRow.appendChild(historyCell);
            
            // Inseriamo la riga dopo quella corrente
            row.after(historyRow);
            
            // Carichiamo lo storico via AJAX
            fetch(`assignment_history.php?computer_id=${computerId}`)
                .then(response => response.text())
                .then(html => {
                    historyCell.innerHTML = html;
                })
                .catch(error => {
                    historyCell.innerHTML = `<div class="alert alert-danger">
                        <i class="ti ti-alert-triangle me-2"></i>
                        Errore nel caricamento dello storico: ${error}
                    </div>`;
                });
        });
    });
});

/**
 * Aggiunge funzionalità di ricerca nella tabella
 */
function addTableSearch() {
    const table = document.querySelector('.inventory-assignments-container table');
    if (!table) return;
    
    // Crea input di ricerca
    const searchContainer = document.createElement('div');
    searchContainer.className = 'mb-3';
    searchContainer.innerHTML = `
        <div class="row">
            <div class="col-md-6">
                <div class="input-group">
                    <span class="input-group-text">
                        <i class="ti ti-search"></i>
                    </span>
                    <input type="text" class="form-control" id="assignmentSearch" 
                           placeholder="Cerca computer, utente, seriale...">
                </div>
            </div>
            <div class="col-md-6 text-end">
                <button class="btn btn-outline-secondary" onclick="clearSearch()">
                    <i class="ti ti-x"></i> Pulisci
                </button>
            </div>
        </div>
    `;
    
    // Inserisci prima della tabella
    table.parentElement.insertBefore(searchContainer, table);
    
    // Aggiungi evento di ricerca
    const searchInput = document.getElementById('assignmentSearch');
    searchInput.addEventListener('input', function() {
        filterTable(this.value.toLowerCase());
    });
}

/**
 * Filtra la tabella in base al testo di ricerca
 */
function filterTable(searchTerm) {
    const table = document.querySelector('.inventory-assignments-container tbody');
    const rows = table.querySelectorAll('tr');
    let visibleCount = 0;
    
    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        if (text.includes(searchTerm)) {
            row.style.display = '';
            visibleCount++;
        } else {
            row.style.display = 'none';
        }
    });
    
    // Aggiorna contatore risultati
    updateSearchResults(visibleCount, rows.length);
}

/**
 * Pulisce la ricerca
 */
function clearSearch() {
    const searchInput = document.getElementById('assignmentSearch');
    if (searchInput) {
        searchInput.value = '';
        filterTable('');
    }
}

/**
 * Aggiorna il contatore dei risultati di ricerca
 */
function updateSearchResults(visible, total) {
    let counter = document.getElementById('searchCounter');
    if (!counter) {
        counter = document.createElement('small');
        counter.id = 'searchCounter';
        counter.className = 'text-muted ms-2';
        const searchInput = document.getElementById('assignmentSearch');
        searchInput.parentElement.parentElement.appendChild(counter);
    }
    
    if (visible === total) {
        counter.textContent = `${total} risultati`;
    } else {
        counter.textContent = `${visible} di ${total} risultati`;
    }
}

/**
 * Aggiorna i contatori dinamici
 */
function updateCounters() {
    const table = document.querySelector('.inventory-assignments-container tbody');
    if (!table) return;
    
    const rows = table.querySelectorAll('tr');
    const totalAssignments = rows.length;
    
    // Aggiorna il contatore nel footer se esiste
    const alertInfo = document.querySelector('.alert-info');
    if (alertInfo) {
        alertInfo.innerHTML = `
            <i class="ti ti-info-circle me-2"></i>
            Totale assegnazioni trovate: <strong>${totalAssignments}</strong>
        `;
    }
}

/**
 * Aggiunge bottone di export (opzionale)
 */
function addExportButton() {
    const cardHeader = document.querySelector('.inventory-assignments-container .card-header');
    if (!cardHeader) return;
    
    const exportBtn = document.createElement('button');
    exportBtn.className = 'btn btn-light btn-sm float-end';
    exportBtn.innerHTML = '<i class="ti ti-download me-1"></i>Esporta CSV';
    exportBtn.onclick = exportToCSV;
    
    cardHeader.appendChild(exportBtn);
}

/**
 * Esporta la tabella in formato CSV
 */
function exportToCSV() {
    const table = document.querySelector('.inventory-assignments-container table');
    if (!table) return;
    
    let csv = [];
    const rows = table.querySelectorAll('tr');
    
    rows.forEach(row => {
        const cols = row.querySelectorAll('td, th');
        const rowData = [];
        
        cols.forEach((col, index) => {
            // Skip dell'ultima colonna (azioni)
            if (index < cols.length - 1) {
                let text = col.textContent.trim();
                // Pulisci il testo da caratteri speciali
                text = text.replace(/"/g, '""');
                rowData.push(`"${text}"`);
            }
        });
        
        if (rowData.length > 0) {
            csv.push(rowData.join(','));
        }
    });
    
    // Crea e scarica il file
    const csvContent = csv.join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    
    if (link.download !== undefined) {
        const url = URL.createObjectURL(blob);
        link.setAttribute('href', url);
        link.setAttribute('download', `assegnazioni_utenti_${new Date().toISOString().split('T')[0]}.csv`);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
}

/**
 * Aggiunge animazioni alle righe della tabella
 */
function addTableAnimations() {
    const rows = document.querySelectorAll('.inventory-assignments-container tbody tr');
    
    rows.forEach((row, index) => {
        row.style.animationDelay = `${index * 0.05}s`;
        row.classList.add('table-row-animate');
    });
}

/**
 * Gestisce il click sui link esterni
 */
document.addEventListener('click', function(e) {
    if (e.target.closest('a[target="_blank"]')) {
        // Aggiungi animazione di click
        const link = e.target.closest('a');
        link.style.transform = 'scale(0.95)';
        setTimeout(() => {
            link.style.transform = 'scale(1)';
        }, 100);
    }
});

/**
 * Aggiunge CSS animations dinamicamente
 */
const style = document.createElement('style');
style.textContent = `
    @keyframes tableRowFadeIn {
        from {
            opacity: 0;
            transform: translateY(10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    .table-row-animate {
        animation: tableRowFadeIn 0.3s ease-out forwards;
        opacity: 0;
    }
    
    .inventory-assignments-container a {
        transition: all 0.15s ease-in-out;
    }
    
    .inventory-assignments-container .btn {
        transition: all 0.15s ease-in-out;
    }
    
    .inventory-assignments-container .btn:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 8px rgba(0,0,0,0.15);
    }
`;
document.head.appendChild(style);
