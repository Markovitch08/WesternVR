@echo off
rem Regenerates the generated scenes and placeholder sounds (tools\scene_builders.gd).
rem Overwrites revolver\, ammo\, range\, player\ and main\ scenes.
if "%GODOT%"=="" set GODOT=godot.exe
"%GODOT%" --headless --path "%~dp0.." --import >nul 2>&1
"%GODOT%" --headless --path "%~dp0.." res://tools/BuildScenes.tscn
