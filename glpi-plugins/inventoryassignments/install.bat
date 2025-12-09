@echo off
REM Script di installazione per Windows - Inventory Assignments Plugin

echo 🚀 Installazione Plugin Inventory Assignments per GLPI
echo ======================================================

REM Verifica presenza GLPI
if not exist "..\..\inc\includes.php" (
    echo ❌ Errore: GLPI non trovato. Esegui questo script dalla cartella plugins\inventoryassignments\
    pause
    exit /b 1
)

echo 📁 Verifica files...

REM Verifica files essenziali
set missing=0

if exist "setup.php" (
    echo ✅ setup.php
) else (
    echo ❌ Mancante: setup.php
    set missing=1
)

if exist "inc\assignment.class.php" (
    echo ✅ inc\assignment.class.php
) else (
    echo ❌ Mancante: inc\assignment.class.php
    set missing=1
)

if exist "front\assignment.php" (
    echo ✅ front\assignment.php
) else (
    echo ❌ Mancante: front\assignment.php
    set missing=1
)

if exist "css\inventoryassignments.css" (
    echo ✅ css\inventoryassignments.css
) else (
    echo ❌ Mancante: css\inventoryassignments.css
    set missing=1
)

if exist "js\inventoryassignments.js" (
    echo ✅ js\inventoryassignments.js
) else (
    echo ❌ Mancante: js\inventoryassignments.js
    set missing=1
)

if %missing%==1 (
    echo.
    echo ❌ Files mancanti rilevati!
    pause
    exit /b 1
)

echo.
echo 📝 PROSSIMI PASSI:
echo 1. Vai in GLPI → Configurazione → Plugin
echo 2. Trova 'Inventory Assignments'
echo 3. Clicca 'Installa' poi 'Attiva'
echo 4. Vai in Inventario → Assegnazioni Utenti
echo.
echo 🔧 Per testare: /plugins/inventoryassignments/front/test.php
echo.
echo ✅ Installazione completata!
pause
