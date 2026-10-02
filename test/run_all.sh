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
state_out="$("$GODOT" --headless --path . --script res://test/run_state_tests.gd 2>&1)"
state_exit=$?
echo "$state_out" | grep -E "^  \[XX\]|^=== [0-9]|RESULT:|FAILED TO LOAD|^!!|SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:"
if [ "$state_exit" -ne 0 ] || echo "$state_out" | grep -qE "SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:"; then
  echo ">>> STATE HARNESS FAILED"; fail=1
fi

echo ""
echo "### integration tests ###"
# 7-T1 (AC 5-7, `6-5b/R24`): PASSIVE leak capture. The three files that have leaked "resources still
# in use at exit" (full-suite runs only, never in isolation) run with -v, so Godot's verbose leak detail
# is in their output, and ANY file whose output carries that message has its FULL output printed. This
# only adds output: the pass/fail test below is unchanged, and the message still fails the suite.
VERBOSE_FILES="test/integration/test_unit_combat_live.gd test/integration/test_charge_telegraph_dispatch_live.gd test/integration/test_card_mode_lift.gd"
shopt -s nullglob
found=0
for t in test/integration/test_*.gd; do
  found=1
  echo "--- $t ---"
  extra=""
  for v in $VERBOSE_FILES; do
    if [ "$t" == "$v" ]; then extra="-v"; fi
  done
  t_out="$("$GODOT" --headless $extra --path . --script "res://$t" 2>&1)"
  t_exit=$?
  if [ -n "$extra" ]; then
    echo "$t_out" | grep -E "RESULT:|SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:|resources still in use|ObjectDB|leaked"
  else
    echo "$t_out" | grep -E "RESULT:|SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:"
  fi
  if [ "$t_exit" -ne 0 ] || echo "$t_out" | grep -qE "SCRIPT ERROR|Parse Error|INVARIANT VIOLATED|^ERROR:"; then
    echo ">>> FAILED: $t"; fail=1
  fi
  if echo "$t_out" | grep -q "resources still in use at exit"; then
    echo "=== FULL OUTPUT for $t (leak message present) ==="
    echo "$t_out"
    echo "=== END FULL OUTPUT for $t ==="
  fi
done
[ "$found" -eq 0 ] && echo "(no integration tests found)"

echo ""
if [ "$fail" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "SOME TESTS FAILED"; fi
exit "$fail"
