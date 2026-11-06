@echo off
setlocal
set "BRANCH_GODOT=%~dp0..\..\Godot_v4.7.1-stable_win64.exe"
if not exist "%BRANCH_GODOT%" set "BRANCH_GODOT=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%BRANCH_GODOT%" (
  echo Open tools/preview_branch_basement.gd with Godot 4.7.
  pause
  exit /b 1
)
start "" "%BRANCH_GODOT%" --path "%~dp0." --script res://tools/preview_branch_basement.gd
