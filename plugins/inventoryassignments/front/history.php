<?php
/**
 * Pagina completa per visualizzare lo storico di tutte le assegnazioni
 */

include ('../../../inc/includes.php');

// Verifica permessi
Session::checkRight("config", READ);

// Header della pagina
Html::header(
    __('Storico Completo Assegnazioni', 'inventoryassignments'), 
    $_SERVER['PHP_SELF'], 
    "assets", 
    "PluginInventoryassignmentsAssignment"
);

echo "<div class='inventory-assignments-container'>";
echo "<div class='row mb-3'>";
echo "<div class='col-md-8'>";
echo "<h2><i class='ti ti-history me-2'></i>" . __('Storico Completo Assegnazioni', 'inventoryassignments') . "</h2>";
echo "</div>";
echo "<div class='col-md-4 text-end'>";
echo "<a href='assignment.php' class='btn btn-primary'>";
echo "<i class='ti ti-arrow-left me-1'></i>Torna alle Assegnazioni Attuali";
echo "</a>";
echo "</div>";
echo "</div>";

// Visualizza lo storico completo di tutte le assegnazioni
PluginInventoryassignmentsAssignment::showAssignmentHistory();

echo "</div>";

// Footer della pagina
Html::footer();
