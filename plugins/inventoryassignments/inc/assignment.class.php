<?php
/**
 * Classe principale per gestire le assegnazioni nel plugin Inventory Assignments
 */

class PluginInventoryassignmentsAssignment extends CommonGLPI {

    // Definiamo il rightname come nelle classi standard di GLPI
    public static $rightname = "computer";

    /**
     * Get the menu name
     */
    static function getMenuName() {
        return __('Assegnazioni Utenti', 'inventoryassignments');
    }

    /**
     * Get the menu content
     */
    static function getMenuContent() {
        global $CFG_GLPI;

        $menu = [];
        $menu['title'] = self::getMenuName();
        $menu['page'] = '/plugins/inventoryassignments/front/assignment.php';
        $menu['icon'] = 'ti ti-users';
        
        return $menu;
    }

    /**
     * Get type name
     */
    static function getTypeName($nb = 0) {
        return _n('Assegnazione', 'Assegnazioni', $nb, 'inventoryassignments');
    }

    /**
     * Get icon
     */
    static function getIcon() {
        return 'ti ti-users';
    }

    /**
     * Check if user can view assignments
     */
    function canViewItem() {
        return Session::getLoginUserID() > 0;
    }

    /**
     * Check if user can create assignments
     */
    function canCreateItem() {
        return Session::haveRight('computer', READ) || Session::haveRight('config', READ);
    }

    /**
     * Display the assignments table
     */
    static function showAssignmentsTable() {
        global $DB;

        echo "<div class='inventory-assignments-container'>";
        echo "<div class='card'>";
        echo "<div class='card-header'>";
        echo "<div class='d-flex justify-content-between align-items-center'>";
        echo "<h3><i class='ti ti-users me-2'></i>" . __('Tabella Assegnazioni Utenti', 'inventoryassignments') . "</h3>";
        echo "<a href='history.php' class='btn btn-light btn-sm'>";
        echo "<i class='ti ti-history me-1'></i>" . __('Storico Completo', 'inventoryassignments');
        echo "</a>";
        echo "</div>";
        echo "</div>";
        echo "<div class='card-body'>";

        // Query per ottenere le assegnazioni
        $query = "SELECT 
                    c.id as computer_id,
                    c.name as computer_name,
                    c.serial as computer_serial,
                    u.id as user_id,
                    u.name as username,
                    CONCAT(u.firstname, ' ', u.realname) as user_fullname,
                    l.completename as location_name,
                    s.name as state_name,
                    c.date_mod as last_update
                  FROM glpi_computers c
                  LEFT JOIN glpi_users u ON c.users_id = u.id
                  LEFT JOIN glpi_locations l ON c.locations_id = l.id
                  LEFT JOIN glpi_states s ON c.states_id = s.id
                  WHERE c.users_id > 0 
                    AND c.is_deleted = 0
                    AND u.is_deleted = 0
                  ORDER BY user_fullname, c.name";

        $result = $DB->query($query);
        
        if ($DB->numrows($result) > 0) {
            echo "<div class='table-responsive'>";
            echo "<table class='table table-striped table-hover'>";
            echo "<thead class='table-dark'>";
            echo "<tr>";
            echo "<th><i class='ti ti-device-desktop me-1'></i>" . __('Computer', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-barcode me-1'></i>" . __('Serial', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-user me-1'></i>" . __('Utente Assegnato', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-map-pin me-1'></i>" . __('Ubicazione', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-circle-dot me-1'></i>" . __('Stato', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-clock me-1'></i>" . __('Ultimo Aggiornamento', 'inventoryassignments') . "</th>";
            echo "<th><i class='ti ti-settings me-1'></i>" . __('Azioni', 'inventoryassignments') . "</th>";
            echo "</tr>";
            echo "</thead>";
            echo "<tbody>";

            while ($row = $DB->fetchAssoc($result)) {
                echo "<tr>";
                
                // Computer name con link
                echo "<td>";
                echo "<a href='" . Computer::getFormURLWithID($row['computer_id']) . "' target='_blank'>";
                echo "<strong>" . htmlspecialchars($row['computer_name']) . "</strong>";
                echo "</a>";
                echo "</td>";
                
                // Serial
                echo "<td>" . htmlspecialchars($row['computer_serial'] ?: '-') . "</td>";
                
                // User
                echo "<td>";
                if ($row['user_id']) {
                    echo "<a href='" . User::getFormURLWithID($row['user_id']) . "' target='_blank'>";
                    echo "<i class='ti ti-user me-1'></i>";
                    echo htmlspecialchars($row['user_fullname'] ?: $row['username']);
                    echo "</a>";
                } else {
                    echo "<span class='text-muted'>-</span>";
                }
                echo "</td>";
                
                // Location
                echo "<td>" . htmlspecialchars($row['location_name'] ?: '-') . "</td>";
                
                // State
                echo "<td>";
                if ($row['state_name']) {
                    echo "<span class='badge bg-info'>" . htmlspecialchars($row['state_name']) . "</span>";
                } else {
                    echo "<span class='text-muted'>-</span>";
                }
                echo "</td>";
                
                // Last update
                echo "<td>";
                if ($row['last_update']) {
                    echo "<small>" . Html::convDateTime($row['last_update']) . "</small>";
                } else {
                    echo "<span class='text-muted'>-</span>";
                }
                echo "</td>";
                
                // Actions
                echo "<td>";            echo "<div class='btn-group btn-group-sm'>";
            echo "<a href='" . Computer::getFormURLWithID($row['computer_id']) . "' class='btn btn-outline-primary btn-sm' target='_blank'>";
            echo "<i class='ti ti-eye'></i>";
            echo "</a>";
            if ($row['user_id']) {
                echo "<a href='" . User::getFormURLWithID($row['user_id']) . "' class='btn btn-outline-success btn-sm' target='_blank'>";
                echo "<i class='ti ti-user'></i>";
                echo "</a>";
            }
            // Aggiungo bottone storico
            echo "<button type='button' class='btn btn-outline-info btn-sm show-history' data-computer-id='" . $row['computer_id'] . "'>";
            echo "<i class='ti ti-history'></i>";
            echo "</button>";
            echo "</div>";
                echo "</td>";
                
                echo "</tr>";
            }

            echo "</tbody>";
            echo "</table>";
            echo "</div>";
            
            // Statistiche
            $total_assignments = $DB->numrows($result);
            echo "<div class='row mt-3'>";
            echo "<div class='col-md-12'>";
            echo "<div class='alert alert-info'>";
            echo "<i class='ti ti-info-circle me-2'></i>";
            echo sprintf(__('Totale assegnazioni trovate: %d', 'inventoryassignments'), $total_assignments);
            echo "</div>";
            echo "</div>";
            echo "</div>";
            
        } else {
            echo "<div class='alert alert-warning'>";
            echo "<i class='ti ti-alert-triangle me-2'></i>";
            echo __('Nessuna assegnazione trovata nel sistema.', 'inventoryassignments');
            echo "</div>";
        }

        echo "</div>"; // card-body
        echo "</div>"; // card
        echo "</div>"; // container
    }

    /**
     * Display additional statistics
     */
    static function showStatistics() {
        global $DB;

        echo "<div class='row mt-4'>";
        
        // Computers senza utente
        echo "<div class='col-md-6'>";
        echo "<div class='card border-warning'>";
        echo "<div class='card-header bg-warning text-dark'>";
        echo "<h5><i class='ti ti-alert-triangle me-2'></i>" . __('Computer Non Assegnati', 'inventoryassignments') . "</h5>";
        echo "</div>";
        echo "<div class='card-body'>";
        
        $query_unassigned = "SELECT COUNT(*) as count 
                           FROM glpi_computers 
                           WHERE (users_id = 0 OR users_id IS NULL) 
                             AND is_deleted = 0";
        $result_unassigned = $DB->query($query_unassigned);
        $unassigned_count = $DB->fetchAssoc($result_unassigned)['count'];
        
        echo "<h3 class='text-warning'>" . $unassigned_count . "</h3>";
        echo "<p class='text-muted'>" . __('Computer senza utente assegnato', 'inventoryassignments') . "</p>";
        echo "</div>";
        echo "</div>";
        echo "</div>";
        
        // Utenti con più computer
        echo "<div class='col-md-6'>";
        echo "<div class='card border-info'>";
        echo "<div class='card-header bg-info text-white'>";
        echo "<h5><i class='ti ti-users me-2'></i>" . __('Utenti Multi-Computer', 'inventoryassignments') . "</h5>";
        echo "</div>";
        echo "<div class='card-body'>";
        
        $query_multi = "SELECT COUNT(*) as count 
                       FROM (
                           SELECT users_id 
                           FROM glpi_computers 
                           WHERE users_id > 0 AND is_deleted = 0 
                           GROUP BY users_id 
                           HAVING COUNT(*) > 1
                       ) as multi_users";
        $result_multi = $DB->query($query_multi);
        $multi_count = $DB->fetchAssoc($result_multi)['count'];
        
        echo "<h3 class='text-info'>" . $multi_count . "</h3>";
        echo "<p class='text-muted'>" . __('Utenti con più di un computer', 'inventoryassignments') . "</p>";
        echo "</div>";
        echo "</div>";
        echo "</div>";
        
        echo "</div>";
    }

    /**
     * Get assignment history for a computer
     */
    static function getAssignmentHistory($computer_id = null) {
        global $DB;

        $where = "";
        if ($computer_id !== null) {
            $where = " AND l.items_id = " . intval($computer_id);
        }

        $query = "SELECT 
            l.id,
            l.items_id as computer_id,
            l.date_mod,
            l.user_name as changed_by,
            c.name as computer_name,
            c.serial as computer_serial,
            SUBSTRING_INDEX(l.old_value, ' (', 1) as old_username,
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(l.old_value, '(', -1), ')', 1) AS UNSIGNED) as old_user_id,
            SUBSTRING_INDEX(l.new_value, ' (', 1) as new_username,
            CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(l.new_value, '(', -1), ')', 1) AS UNSIGNED) as new_user_id,
            old_u.firstname as old_firstname,
            old_u.realname as old_realname,
            new_u.firstname as new_firstname,
            new_u.realname as new_realname
        FROM glpi_logs l
        JOIN glpi_computers c ON c.id = l.items_id
        LEFT JOIN glpi_users old_u ON old_u.id = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(l.old_value, '(', -1), ')', 1) AS UNSIGNED)
        LEFT JOIN glpi_users new_u ON new_u.id = CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(l.new_value, '(', -1), ')', 1) AS UNSIGNED)
        WHERE l.itemtype = 'Computer' 
        AND l.id_search_option = 70 " . $where . "
        ORDER BY l.items_id, l.date_mod DESC";

        return $DB->query($query);
    }

    /**
     * Display assignment history
     */
    static function showAssignmentHistory($computer_id = null) {
        global $DB;

        $result = self::getAssignmentHistory($computer_id);
        
        if ($DB->numrows($result) > 0) {
            echo "<div class='mt-4'>";
            echo "<h4><i class='ti ti-history me-2'></i>" . __('Storico Assegnazioni', 'inventoryassignments') . "</h4>";
            echo "<div class='table-responsive'>";
            echo "<table class='table table-sm table-hover'>";
            echo "<thead class='table-light'>";
            echo "<tr>";
            echo "<th>" . __('Data', 'inventoryassignments') . "</th>";
            echo "<th>" . __('Computer', 'inventoryassignments') . "</th>";
            echo "<th>" . __('Da Utente', 'inventoryassignments') . "</th>";
            echo "<th>" . __('A Utente', 'inventoryassignments') . "</th>";
            echo "<th>" . __('Modificato da', 'inventoryassignments') . "</th>";
            echo "</tr>";
            echo "</thead><tbody>";

            while ($row = $DB->fetchAssoc($result)) {
                echo "<tr>";
                
                // Data
                echo "<td><small>" . Html::convDateTime($row['date_mod']) . "</small></td>";
                
                // Computer
                echo "<td>";
                echo "<a href='" . Computer::getFormURLWithID($row['computer_id']) . "' class='text-dark' target='_blank'>";
                echo "<i class='ti ti-device-desktop me-1'></i>";
                echo $row['computer_name'];
                if ($row['computer_serial']) {
                    echo " <small class='text-muted'>(" . $row['computer_serial'] . ")</small>";
                }
                echo "</a>";
                echo "</td>";
                
                // Da Utente
                echo "<td>";
                if ($row['old_user_id'] > 0) {
                    echo "<a href='" . User::getFormURLWithID($row['old_user_id']) . "' class='text-danger' target='_blank'>";
                    echo "<i class='ti ti-user-minus me-1'></i>";
                    if ($row['old_firstname'] && $row['old_realname']) {
                        echo $row['old_firstname'] . ' ' . $row['old_realname'];
                    } else {
                        echo $row['old_username'];
                    }
                    echo "</a>";
                } else {
                    echo "<span class='text-muted'><i class='ti ti-minus me-1'></i>Nessuno</span>";
                }
                echo "</td>";
                
                // A Utente
                echo "<td>";
                if ($row['new_user_id'] > 0) {
                    echo "<a href='" . User::getFormURLWithID($row['new_user_id']) . "' class='text-success' target='_blank'>";
                    echo "<i class='ti ti-user-plus me-1'></i>";
                    if ($row['new_firstname'] && $row['new_realname']) {
                        echo $row['new_firstname'] . ' ' . $row['new_realname'];
                    } else {
                        echo $row['new_username'];
                    }
                    echo "</a>";
                } else {
                    echo "<span class='text-muted'><i class='ti ti-minus me-1'></i>Nessuno</span>";
                }
                echo "</td>";
                
                // Modificato da
                echo "<td><small class='text-muted'>" . $row['changed_by'] . "</small></td>";
                
                echo "</tr>";
            }
            
            echo "</tbody></table>";
            echo "</div>"; // table-responsive
            echo "</div>"; // mt-4
        }
    }
}
