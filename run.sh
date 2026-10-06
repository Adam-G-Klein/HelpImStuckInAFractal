#!/bin/sh
# Launch Help I'm Stuck In A Fractal from the terminal.
#
#   ./run.sh            run the project
#   ./run.sh --editor   open it in the Godot editor instead
#
# Set GODOT to point at a different Godot 4 binary if needed.
set -e
cd "$(dirname "$0")"

GODOT="${GODOT:-godot4}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  if [ -x /Applications/Godot_mono.app/Contents/MacOS/Godot ]; then
    GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot
  elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    GODOT=/Applications/Godot.app/Contents/MacOS/Godot
  else
    echo "Godot 4 not found. Install it or set GODOT=/path/to/godot" >&2
    exit 1
  fi
fi

if [ "$1" = "--editor" ]; then
  shift
  exec "$GODOT" --editor --path . "$@"
fi

# Refresh the script class cache when a script is newer than it, or declares a
# class_name the cache has not heard of (the editor does this on open; this
# project is run from the terminal, so do it here).
CACHE=.godot/global_script_class_cache.cfg
needs_import() {
  [ -f "$CACHE" ] || return 0
  if [ -n "$(find src tests -name '*.gd' -newer "$CACHE" -print 2>/dev/null | head -n 1)" ]; then
    return 0
  fi
  find src tests -name '*.gd' -exec grep -hoE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' {} + 2>/dev/null \
    | awk '{ print $2 }' \
    | while IFS= read -r cls; do
        grep -q "\"class\": &\"$cls\"" "$CACHE" || echo "$cls"
      done \
    | grep -q .
}
if needs_import; then
  echo "Refreshing Godot's script class cache (import step)..." >&2
  "$GODOT" --headless --import --path . >/dev/null 2>&1 || true
fi

exec "$GODOT" --path . "$@"
