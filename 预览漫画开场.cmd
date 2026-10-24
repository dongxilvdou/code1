@echo off
setlocal
set "GODOT_EXE=%~dp0..\..\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Godot 4.7 was not found. Open scenes/cinematics/OpeningPreview.tscn in Godot and press F6.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." res://scenes/cinematics/OpeningPreview.tscn
