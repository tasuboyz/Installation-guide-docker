# Configurazione accesso n8n a MariaDB (GLPI)

Per permettere a n8n di accedere anche al database di GLPI (MariaDB), aggiungi una credenziale MySQL/MariaDB in n8n con questi parametri:
- Host: `mariadb`
- Database: `glpidb`
- User: `glpi`
- Password: `GlpiPass2024#`
- Porta: `3306`

n8n potrà così leggere e scrivere sul database di GLPI tramite i nodi SQL.
