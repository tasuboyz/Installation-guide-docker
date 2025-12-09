<?php
/**
 * Test script per verificare il funzionamento del plugin Inventory Assignments
 */

// Carica il framework GLPI
include ('../../../inc/includes.php');

echo "<!DOCTYPE html>";
echo "<html><head><title>Test Inventory Assignments Plugin</title>";
echo "<style>body{font-family:Arial;margin:40px;} .test{padding:10px;margin:10px;border-radius:5px;} .pass{background:#d4edda;border:1px solid #c3e6cb;} .fail{background:#f8d7da;border:1px solid #f5c6cb;}</style>";
echo "</head><body>";

echo "<h1>🧪 Test Plugin Inventory Assignments</h1>";

// Test 1: Verifica caricamento plugin
echo "<div class='test ";
if (class_exists('PluginInventoryassignmentsAssignment')) {
    echo "pass'>✅ Classe PluginInventoryassignmentsAssignment caricata correttamente";
} else {
    echo "fail'>❌ Errore: Classe PluginInventoryassignmentsAssignment non trovata";
}
echo "</div>";

// Test 2: Verifica connessione database
echo "<div class='test ";
try {
    global $DB;
    $result = $DB->query("SELECT COUNT(*) FROM glpi_computers LIMIT 1");
    echo "pass'>✅ Connessione database funzionante";
} catch (Exception $e) {
    echo "fail'>❌ Errore connessione database: " . $e->getMessage();
}
echo "</div>";

// Test 3: Verifica query assegnazioni
echo "<div class='test ";
try {
    global $DB;
    $query = "SELECT COUNT(*) as count FROM glpi_computers c 
              LEFT JOIN glpi_users u ON c.users_id = u.id 
              WHERE c.users_id > 0 AND c.is_deleted = 0";
    $result = $DB->query($query);
    $count = $DB->fetchAssoc($result)['count'];
    echo "pass'>✅ Query assegnazioni OK - Trovate $count assegnazioni";
} catch (Exception $e) {
    echo "fail'>❌ Errore query assegnazioni: " . $e->getMessage();
}
echo "</div>";

// Test 4: Verifica permessi
echo "<div class='test ";
if (Session::haveRight("config", READ)) {
    echo "pass'>✅ Utente ha permessi di lettura configurazione";
} else {
    echo "fail'>❌ Utente non ha permessi sufficienti";
}
echo "</div>";

// Test 5: Verifica files CSS/JS
echo "<div class='test ";
$css_file = GLPI_ROOT . '/plugins/inventoryassignments/css/inventoryassignments.css';
$js_file = GLPI_ROOT . '/plugins/inventoryassignments/js/inventoryassignments.js';
if (file_exists($css_file) && file_exists($js_file)) {
    echo "pass'>✅ Files CSS e JavaScript presenti";
} else {
    echo "fail'>❌ Files CSS o JavaScript mancanti";
}
echo "</div>";

// Test 6: Test metodi della classe
echo "<div class='test ";
try {
    $menuName = PluginInventoryassignmentsAssignment::getMenuName();
    $typeName = PluginInventoryassignmentsAssignment::getTypeName();
    $icon = PluginInventoryassignmentsAssignment::getIcon();
    echo "pass'>✅ Metodi classe funzionanti - Menu: $menuName, Tipo: $typeName, Icona: $icon";
} catch (Exception $e) {
    echo "fail'>❌ Errore metodi classe: " . $e->getMessage();
}
echo "</div>";

// Test 7: Test rendering tabella (simulato)
echo "<div class='test ";
try {
    ob_start();
    PluginInventoryassignmentsAssignment::showAssignmentsTable();
    $output = ob_get_clean();
    if (strlen($output) > 100) {
        echo "pass'>✅ Tabella assegnazioni renderizzata correttamente";
    } else {
        echo "fail'>❌ Problema nel rendering della tabella";
    }
} catch (Exception $e) {
    echo "fail'>❌ Errore rendering tabella: " . $e->getMessage();
}
echo "</div>";

// Test 8: Test statistiche
echo "<div class='test ";
try {
    ob_start();
    PluginInventoryassignmentsAssignment::showStatistics();
    $output = ob_get_clean();
    if (strlen($output) > 50) {
        echo "pass'>✅ Statistiche renderizzate correttamente";
    } else {
        echo "fail'>❌ Problema nel rendering delle statistiche";
    }
} catch (Exception $e) {
    echo "fail'>❌ Errore rendering statistiche: " . $e->getMessage();
}
echo "</div>";

echo "<h2>📋 Test Completato</h2>";
echo "<p>Se tutti i test sono passati (✅), il plugin è pronto per l'uso!</p>";
echo "<p><a href='assignment.php'>→ Vai alla pagina principale del plugin</a></p>";

echo "</body></html>";
