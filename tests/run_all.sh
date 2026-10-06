#!/bin/sh
# Run every headless test (tests/*_test.gd) after refreshing the class cache.
# Exit status is non-zero if any test fails, errors, or fails to parse.
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-godot4}"
"$GODOT" --headless --import --path . >/dev/null 2>&1
status=0
for t in tests/*_test.gd; do
  echo "=== $t"
  out=$("$GODOT" --headless --path . -s "$t" 2>&1)
  code=$?
  printf '%s\n' "$out" | grep -vE '^Godot Engine|^$'
  if [ "$code" -ne 0 ] || printf '%s' "$out" | grep -qE 'SCRIPT ERROR|Failed to load script| FAILED'; then
    status=1
    echo "*** $t FAILED (exit $code)"
  fi
done
exit $status
