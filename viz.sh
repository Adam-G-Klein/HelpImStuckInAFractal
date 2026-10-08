#!/usr/bin/env bash
# Opens the systems viz (docs/viz/index.html) in your default browser: a row of panes (one per
# visualized system), a row of the open pane's tabs, and one pannable, zoomable canvas per tab.
# Add a system with the /visualize skill.
#
#   ./viz.sh             the first pane's first tab
#   ./viz.sh fog-sim     one pane (its id in docs/viz/panes/<id>.js), at its first tab
#   ./viz.sh fog-sim/3   that pane's third tab
#
# Always opens the MAIN checkout's copy, resolved through git's common dir (shared by every
# worktree), never a frozen .claude/worktrees one: a worktree carries a copy of docs/viz frozen at
# its branch state and would silently show an outdated viz. Do not "simplify" this back to a path
# relative to the script.
set -euo pipefail

VIZ_REL="docs/viz/index.html"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if GIT_COMMON="$(git -C "$SCRIPT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  ROOT="$(dirname "$GIT_COMMON")"
else
  ROOT="$SCRIPT_DIR"
fi
VIZ="$ROOT/$VIZ_REL"
if [[ ! -f "$VIZ" ]]; then
  echo "Visualization not found at: $VIZ" >&2
  exit 1
fi

URL="file://$VIZ"
if [[ $# -gt 0 ]]; then
  if [[ ! -f "$ROOT/docs/viz/panes/${1%%/*}.js" ]]; then
    echo "No pane '${1%%/*}'. Panes: $(cd "$ROOT/docs/viz/panes" && ls *.js | sed 's/\.js$//' | tr '\n' ' ')" >&2
    exit 1
  fi
  URL="$URL#$1"
fi

# A plain `open file://...#frag` resolves to the file and drops the #fragment, so hand the URL to
# the default browser app directly (no https handler registered = Safari, the macOS default).
BROWSER_ID="$(defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers 2>/dev/null \
  | grep -B1 -A3 '"https"' | sed -n 's/.*LSHandlerRoleAll = "\(.*\)";/\1/p' | head -1 || true)"
open -b "${BROWSER_ID:-com.apple.Safari}" "$URL"
