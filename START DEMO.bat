@echo off
title SimHaptic Full Demo
cd /d "%~dp0"
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SimHapticDemo.ps1"
pause
