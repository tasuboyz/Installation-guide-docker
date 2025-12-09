#!/bin/bash
# Script di installazione automatica per Inventory Assignments Plugin

echo "🚀 Installazione Plugin Inventory Assignments per GLPI"
echo "======================================================"

# Verifica presenza GLPI
if [ ! -f "../../inc/includes.php" ]; then
    echo "❌ Errore: GLPI non trovato. Esegui questo script dalla cartella plugins/inventoryassignments/"
    exit 1
fi

# Imposta permessi
echo "📁 Impostazione permessi..."
chmod -R 755 .
chown -R www-data:www-data . 2>/dev/null || echo "⚠️  Non è possibile cambiare owner (normale se non sei root)"

# Verifica files essenziali
echo "🔍 Verifica files..."
required_files=(
    "setup.php"
    "inc/assignment.class.php" 
    "front/assignment.php"
    "css/inventoryassignments.css"
    "js/inventoryassignments.js"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ Mancante: $file"
        exit 1
    fi
done

echo ""
echo "📝 PROSSIMI PASSI:"
echo "1. Vai in GLPI → Configurazione → Plugin"
echo "2. Trova 'Inventory Assignments'"
echo "3. Clicca 'Installa' poi 'Attiva'"
echo "4. Vai in Inventario → Assegnazioni Utenti"
echo ""
echo "🔧 Per testare: /plugins/inventoryassignments/front/test.php"
echo ""
echo "✅ Installazione completata!"
