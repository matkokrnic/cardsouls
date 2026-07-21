#!/usr/bin/env bash
# Runs ALL CardSouls tests: the headless state harness + every integration test.
# Exits nonzero if any suite fails, so it is safe for CI / pre-push.
#
# Usage:   bash test/run_all.sh
# Godot:   override the binary with GODOT=/path/to/godot (default: /c/Godot/godot)
# Fresh clone: if a test fails to LOAD, build the class cache once (see README) then re-run:
#   godot --headless --editor --quit --path .

set -o pipefail
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-/c/Godot/godot}"
fail=0

echo "### state harness ###"
"$GODOT" --headless --path . --script res://test/run_state_tests.gd 2>&1 \
  | grep -E "^  \[XX\]|^=== [0-9]|RESULT:|FAILED TO LOAD|^!!"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then echo ">>> STATE HARNESS FAILED"; fail=1; fi

echo ""
echo "### integration tests ###"
shopt -s nullglob
found=0
for t in test/integration/test_*.gd; do
  found=1
  echo "--- $t ---"
  "$GODOT" --headless --path . --script "res://$t" 2>&1 \
    | grep -E "RESULT:|SCRIPT ERROR|Parse Error|INVARIANT VIOLATED"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then echo ">>> FAILED: $t"; fail=1; fi
done
[ "$found" -eq 0 ] && echo "(no integration tests found)"

echo ""
if [ "$fail" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit "$fail"
