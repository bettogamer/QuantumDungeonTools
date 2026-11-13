@echo off
REM deploy-local.bat - wrapper doble-clic para deploy-local.ps1
REM Copiar a scripts/deploy-local.bat junto al .ps1 (no necesita ajustes: no conoce el addon).
REM Existe para que el owner despliegue sin abrir una terminal ni pelearse con ExecutionPolicy;
REM deja la ventana abierta para poder leer el resultado. Los args se pasan tal cual
REM (p. ej. deploy-local.bat -AddOnsPath "D:\WoW\_retail_\Interface\AddOns").
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-local.ps1" %*
echo.
echo === Terminado. Usa /reload en el juego. ===
pause
