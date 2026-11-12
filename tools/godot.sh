#!/usr/bin/env bash
# Runs Godot for this project. Set GODOT to your Godot 4.7 editor binary.
GODOT="${GODOT:-godot}"
exec "$GODOT" --path "$(cd "$(dirname "$0")/.." && pwd)" "$@"
