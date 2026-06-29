@echo off
title TJ Photo Editor (Web)
cd /d "%~dp0"
where flutter >nul 2>nul || set "PATH=%USERPROFILE%\flutter\bin;%PATH%"
echo ==================================================
echo   TJ Photo Editor - launching in Chrome
echo.
echo   The FIRST launch compiles for about a minute,
echo   then Chrome opens by itself. Keep this window
echo   open while you use the app. Close it to stop.
echo ==================================================
echo.
flutter run -d chrome
echo.
echo App stopped. Press any key to close.
pause >nul
