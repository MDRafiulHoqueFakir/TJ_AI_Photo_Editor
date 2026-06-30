@echo off
title TJ Photo Editor - AI Diagnosis
cd /d "%~dp0"
node "tools\diagnose.js"
echo.
echo Copy everything above and paste it back in the chat.
echo.
pause
