@echo off
rem Runs the GUT unit tests headless. Set GODOT to your godot.exe first, e.g.
rem   set GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe
rem   tools\test.bat                         (all tests)
rem   tools\test.bat -gselect=test_mechanism (one file)
if "%GODOT%"=="" set GODOT=godot.exe
"%GODOT%" --headless --path "%~dp0.." --import >nul 2>&1
"%GODOT%" --headless --path "%~dp0.." -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json %*
