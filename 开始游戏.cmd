@echo off
set "GODOT=C:\zGoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot 4.7.1 was not found. Please open project.godot in Godot.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
