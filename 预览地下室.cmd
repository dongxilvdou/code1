@echo off
setlocal
set "LAB_GODOT=%~dp0..\..\Godot_v4.7.1-stable_win64.exe"
if not exist "%LAB_GODOT%" set "LAB_GODOT=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%LAB_GODOT%" (
  echo Godot executable was not found. Run tools/preview_basement.gd with Godot 4.7.
  pause
  exit /b 1
)
start "" "%LAB_GODOT%" --path "%~dp0." --script res://tools/preview_basement.gd
