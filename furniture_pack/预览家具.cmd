@echo off
set "GODOT_EXE=C:\zGoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot executable not found. Open furniture_pack/preview.tscn in Godot and press F6.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0.." res://furniture_pack/preview.tscn
