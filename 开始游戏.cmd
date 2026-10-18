@echo off
setlocal
set "GODOT_EXE=D:\steam1\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=C:\zGoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" set "GODOT_EXE=C:\GoDot\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
 echo Godot was not found. Import project.godot in Godot 4.7 or newer.
 pause
 exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0."
