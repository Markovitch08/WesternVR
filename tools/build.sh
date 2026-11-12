#!/usr/bin/env bash
# Regenerates the generated scenes (see tools/scene_builders.gd).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . res://tools/BuildScenes.tscn 2>&1 | grep -vE "OpenXR|openxr|xrEnumerate|StartXR|Check logged|requested but failed|^\s+at:|^\s+\[[0-9]\]|Custom solver bias"
