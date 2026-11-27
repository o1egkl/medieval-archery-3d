@echo off
setlocal EnableDelayedExpansion
title Medieval Archery Range 3D - Windows Launcher
cd /d "%~dp0"
set GAME_URL=https://o1egk.github.io/medieval-archery-3d/

if exist "builds\windows\MedievalArchery3D.exe" goto :run_exe

:: 1. Prefer non-console Godot 4 GUI executable (no command prompt window)
set "GODOT_GUI="
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
	for /f "delims=" %%F in ('dir /b /s "%%~fD\Godot*_win64.exe" 2^>nul') do (
		echo %%~nxF | findstr /i "_console" >nul
		if errorlevel 1 set "GODOT_GUI=%%F"
	)
)
if defined GODOT_GUI goto :run_godot_gui

:: 2. Check godot / godot4 in PATH (resolve sibling GUI .exe if godot.cmd wraps *_console.exe)
for %%C in (godot godot4) do (
	for /f "delims=" %%P in ('where %%C 2^>nul') do (
		if /i "%%~xP"==".exe" (
			echo %%~nxP | findstr /i "_console" >nul
			if errorlevel 1 (
				set "GODOT_GUI=%%P"
				goto :run_godot_gui
			)
		) else (
			for /f "tokens=*" %%L in ('findstr /i "Godot" "%%P" 2^>nul') do (
				for %%A in (%%L) do (
					set "CAND=%%~A"
					set "CAND=!CAND:_console.exe=.exe!"
					if exist "!CAND!" (
						echo !CAND! | findstr /i "\.exe$" >nul
						if not errorlevel 1 (
							set "GODOT_GUI=!CAND!"
							goto :run_godot_gui
						)
					)
				)
			)
		)
	)
)

where godot >nul 2>nul
if %errorlevel%==0 (
	set "GODOT_CLI=godot"
	goto :run_godot_cli
)
where godot4 >nul 2>nul
if %errorlevel%==0 (
	set "GODOT_CLI=godot4"
	goto :run_godot_cli
)

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" goto :run_chrome64
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" goto :run_chrome86
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" goto :run_edge86
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" goto :run_edge64
goto :run_default

:run_exe
echo Launching standalone Windows EXE...
start "" "builds\windows\MedievalArchery3D.exe"
exit /b 0

:run_godot_gui
if not exist ".godot" "%GODOT_GUI%" --headless --import --quit >nul 2>nul
echo Launching in local Godot 4...
start "" "%GODOT_GUI%" --path .
exit /b 0

:run_godot_cli
if not exist ".godot" call %GODOT_CLI% --headless --import --quit >nul 2>nul
echo Launching in local Godot 4...
start "" /min cmd /c "%GODOT_CLI% --path ."
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
