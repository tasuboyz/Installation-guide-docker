<?php
/**
 * Plugin Inventory Assignments per GLPI
 * Aggiunge un menu nella sezione Inventario per visualizzare le assegnazioni utenti
 */

define('PLUGIN_INVENTORYASSIGNMENTS_VERSION', '1.0.0');
define('PLUGIN_INVENTORYASSIGNMENTS_MIN_GLPI', '10.0.0');

/**
 * Autoload delle classi del plugin
 */
function plugin_inventoryassignments_autoload($classname) {
    if (strpos($classname, 'PluginInventoryassignments') === 0) {
        $classname = str_replace('PluginInventoryassignments', '', $classname);
        $classfile = strtolower($classname);
        $file = GLPI_ROOT . '/plugins/inventoryassignments/inc/' . $classfile . '.class.php';
        
        if (file_exists($file)) {
            require_once($file);
            return true;
        }
    }
    return false;
}

spl_autoload_register('plugin_inventoryassignments_autoload');

/**
 * Initialize plugin
 */
function plugin_init_inventoryassignments() {
    global $PLUGIN_HOOKS;
    
    $PLUGIN_HOOKS['csrf_compliant']['inventoryassignments'] = true;
    
    // Hook per aggiungere il menu nella sezione Assets (Inventario) - SEMPRE visibile
    if (Session::getLoginUserID()) {
        $PLUGIN_HOOKS['menu_toadd']['inventoryassignments'] = [
            'assets' => 'PluginInventoryassignmentsAssignment'
        ];
    }
    
    // Hook per caricare CSS
    $PLUGIN_HOOKS['add_css']['inventoryassignments'] = 'css/inventoryassignments.css';
    
    // Hook per caricare JavaScript
    $PLUGIN_HOOKS['add_javascript']['inventoryassignments'] = 'js/inventoryassignments.js';
    
    // Aggiungi permessi
    Plugin::registerClass('PluginInventoryassignmentsAssignment', [
        'notificationtemplates_types' => true
    ]);
    
    // Il plugin usa i permessi standard dei computer
    // Nessun permesso personalizzato necessario
}

/**
 * Version information
 */
function plugin_version_inventoryassignments() {
    return [
        'name'           => 'Inventory Assignments',
        'version'        => PLUGIN_INVENTORYASSIGNMENTS_VERSION,
        'author'         => 'Tasuboyz',
        'license'        => 'GPL v3+',
        'homepage'       => '',
        'requirements'   => [
            'glpi' => [
                'min' => PLUGIN_INVENTORYASSIGNMENTS_MIN_GLPI,
            ]
        ]
    ];
}

/**
 * Install plugin
 */
function plugin_inventoryassignments_install() {
    return true; // Nessuna configurazione speciale necessaria
}

/**
 * Uninstall plugin
 */
function plugin_inventoryassignments_uninstall() {
    return true;
}

/**
 * Check if plugin can be installed
 */
function plugin_inventoryassignments_check_prerequisites() {
    if (version_compare(GLPI_VERSION, PLUGIN_INVENTORYASSIGNMENTS_MIN_GLPI, 'lt')) {
        echo __('This plugin requires GLPI >= ' . PLUGIN_INVENTORYASSIGNMENTS_MIN_GLPI);
        return false;
    }
    return true;
}

/**
 * Check if plugin configuration is OK
 */
function plugin_inventoryassignments_check_config() {
    return true;
}
