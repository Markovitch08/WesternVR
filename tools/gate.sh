#!/usr/bin/env bash
# Full gate before a commit: regenerate scenes, headless smoke check, all tests.
# Exits non-zero if anything fails.
set -e
cd "$(dirname "$0")/.."
mkdir -p .tmp
tools/build.sh > .tmp/build.log 2>&1 || { cat .tmp/build.log; exit 1; }
if grep -E "SCRIPT ERROR|Parse Error|failed to save" .tmp/build.log; then exit 1; fi
tools/check.sh
tools/test.sh > .tmp/test.log 2>&1 || { grep -E "\[Failed|expected|Failing|SCRIPT ERROR" .tmp/test.log | sort | uniq -c | head -30; echo "TESTS FAILED"; exit 1; }
if grep -q "SCRIPT ERROR" .tmp/test.log; then grep "SCRIPT ERROR" .tmp/test.log | sort | uniq -c | head; echo "SCRIPT ERRORS DURING TESTS"; exit 1; fi
grep -E "Scripts|Tests |Passing|Asserts" .tmp/test.log | sed 's/\x1b\[[0-9;]*m//g'
echo "GATE OK"
