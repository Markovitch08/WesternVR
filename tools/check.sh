#!/usr/bin/env bash
# Headless smoke check: imports the project, loads the main scene for ~2 s of
# frames and fails if Godot printed any script/parse/load error.
#   GODOT=/path/to/godot tools/check.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG=.tmp/check.log
mkdir -p .tmp
"$GODOT" --headless --path . --import >"$LOG.import" 2>&1
"$GODOT" --headless --path . --quit-after 180 res://main/Main.tscn >"$LOG" 2>&1
cat "$LOG.import" "$LOG" \
  | grep -E "SCRIPT ERROR|Parse Error|ERROR:" \
  | grep -vE "OpenXR|XR Tools|StartXR|xr_interface|Unable to initialize|openxr" \
  | grep -v "Custom solver bias" > .tmp/check.errors || true
if [ -s .tmp/check.errors ]; then
  echo "CHECK FAILED:"; cat .tmp/check.errors; exit 1
fi
echo "CHECK OK: project imports and Main.tscn runs headless without errors"
