#!/usr/bin/env bash
# Runs the GUT unit tests headless. Exit code 0 = all passed.
#   GODOT=/path/to/godot tools/test.sh            (all tests)
#   GODOT=/path/to/godot tools/test.sh -gselect=test_mechanism   (one file)
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p tests/results
"$GODOT" --headless --path . --import >/dev/null 2>&1
exec "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
