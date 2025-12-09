<?php
/**
 * AJAX endpoint per caricare lo storico assegnazioni di un singolo computer
 */

include ('../../../inc/includes.php');

// Verifica permessi
Session::checkRight("config", READ);

// Verifica parametri
if (!isset($_GET['computer_id']) || !is_numeric($_GET['computer_id'])) {
    http_response_code(400);
    echo "<div class='alert alert-danger'>Parametro computer_id mancante o non valido</div>";
    exit;
}

$computer_id = intval($_GET['computer_id']);

// Chiama il metodo per visualizzare lo storico del singolo computer
PluginInventoryassignmentsAssignment::showAssignmentHistory($computer_id);
