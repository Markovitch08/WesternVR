@echo off
rem Loads the project and runs Main.tscn headless for ~2 s. Look for "SCRIPT ERROR".
if "%GODOT%"=="" set GODOT=godot.exe
"%GODOT%" --headless --path "%~dp0.." --import
"%GODOT%" --headless --path "%~dp0.." --quit-after 180 res://main/Main.tscn
