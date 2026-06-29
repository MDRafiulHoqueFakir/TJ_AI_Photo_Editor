@echo off
title TJ Photo Editor (Web - release)
cd /d "%~dp0"
where flutter >nul 2>nul || set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
echo Building optimized release web build (one-time, ~1-2 min)...
call flutter build web || goto :err
echo.
echo Serving at http://localhost:8080
start "" http://localhost:8080
npx --yes serve build\web -l 8080
goto :eof
:err
echo.
echo Build failed. Press any key to close.
pause >nul
