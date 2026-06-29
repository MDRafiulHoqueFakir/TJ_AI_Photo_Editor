@echo off
title TJ Photo Editor (Web)
cd /d "%~dp0"
where flutter >nul 2>nul || set "PATH=%USERPROFILE%\flutter\bin;%PATH%"

if not exist "build\web\index.html" (
  echo First-time setup: building the app ^(about 1-2 minutes^)...
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
