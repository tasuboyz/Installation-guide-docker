<?php
/**
 * Front page per visualizzare le assegnazioni utenti
 */

include ('../../../inc/includes.php');

// Debug per capire il problema
echo "<h2>Debug Plugin:</h2>";
echo "Classe esiste: " . (class_exists('PluginInventoryassignmentsAssignment') ? 'SI' : 'NO') . "<br>";

if (class_exists('PluginInventoryassignmentsAssignment')) {
    echo "Rightname: " . PluginInventoryassignmentsAssignment::$rightname . "<br>";
    echo "Permesso computer READ: " . (Session::haveRight('computer', READ) ? 'SI' : 'NO') . "<br>";
    echo "Permesso tramite rightname: " . (Session::haveRight(PluginInventoryassignmentsAssignment::$rightname, READ) ? 'SI' : 'NO') . "<br>";
} else {
    echo "La classe non è stata caricata correttamente<br>";
}

// Test semplificato - usa direttamente 'computer'
Session::checkRight("computer", READ);

// Header della pagina
Html::header(
    __('Assegnazioni Utenti', 'inventoryassignments'), 
    $_SERVER['PHP_SELF'], 
    "assets", 
    "PluginInventoryassignmentsAssignment"
);

// Visualizza la tabella delle assegnazioni
PluginInventoryassignmentsAssignment::showAssignmentsTable();

// Visualizza le statistiche aggiuntive
PluginInventoryassignmentsAssignment::showStatistics();

// Footer della pagina
Html::footer();
