@echo off
setlocal enabledelayedexpansion
title TJ Photo Editor (Web)
cd /d "%~dp0"
where flutter >nul 2>nul || set "PATH=%USERPROFILE%\flutter\bin;%PATH%"

REM --- Rebuild if there's no build or the bootstrap is corrupt/empty. ---
set "REBUILD="
if not exist "build\web\index.html" set "REBUILD=1"
if not exist "build\web\flutter_bootstrap.js" set "REBUILD=1"
for %%A in ("build\web\flutter_bootstrap.js") do if %%~zA LSS 100 set "REBUILD=1"
if defined REBUILD (
  echo Building the app ^(about 1-2 minutes^)...
  call flutter build web || goto :err
)

echo.
echo ==================================================
echo   TJ Photo Editor is starting...
echo   Opening http://localhost:8080 in your browser.
echo   Keep this window open while using the app.
echo ==================================================
echo.
start "" http://localhost:8080
node "tools\serve.js"
goto :eof

:err
echo.
echo Build failed. Make sure Flutter is installed. Press any key to close.
pause >nul
