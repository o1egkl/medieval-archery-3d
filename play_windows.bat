@echo off
setlocal
title Medieval Archery Range 3D - Windows Launcher
cd /d "%~dp0"
set GAME_URL=https://o1egkl.github.io/medieval-archery-3d/

if exist "builds\windows\MedievalArchery3D.exe" goto :run_exe
where godot >nul 2>nul
if %errorlevel%==0 goto :run_godot
where godot4 >nul 2>nul
if %errorlevel%==0 goto :run_godot4
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" goto :run_chrome64
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" goto :run_chrome86
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" goto :run_edge86
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" goto :run_edge64
goto :run_default

:run_exe
echo Launching standalone Windows EXE...
start "" "builds\windows\MedievalArchery3D.exe"
exit /b 0

:run_godot
if not exist ".godot" godot --headless --import --quit >nul 2>nul
echo Launching in local Godot 4...
start "" godot --path .
exit /b 0

:run_godot4
if not exist ".godot" godot4 --headless --import --quit >nul 2>nul
echo Launching in local Godot 4...
start "" godot4 --path .
exit /b 0

:run_chrome64
echo Launching standalone app window (Chrome)...
start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --app=%GAME_URL% --window-size=1280,720
exit /b 0

:run_chrome86
echo Launching standalone app window (Chrome)...
start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" --app=%GAME_URL% --window-size=1280,720
exit /b 0

:run_edge86
echo Launching standalone app window (Edge)...
start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app=%GAME_URL% --window-size=1280,720
exit /b 0

:run_edge64
echo Launching standalone app window (Edge)...
start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app=%GAME_URL% --window-size=1280,720
exit /b 0

:run_default
echo Opening game in default browser...
start "" "%GAME_URL%"
exit /b 0
