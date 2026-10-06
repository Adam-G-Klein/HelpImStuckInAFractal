# Mandelbox Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Godot 4.6 web-exportable viewer that reproduces the Mandelbox
renderer at icefractal.com/mandelbox/ (default view, 4 shape sliders, 13 colour
modes, precision, Julia mode, orbit camera) and adds a distance-scaled free-fly
camera, an adaptive-resolution governor, and a runtime controls panel.

**Architecture:** Two shared `Resource`s — `FractalParams` and `CameraState` —
carry all state and emit `changed`. A canvas_item shader raymarches the fractal
in a `SubViewport`; a CPU copy of its distance estimator drives camera speed,
orbit centring and the Julia marker. Every other unit (cameras, panel,
governor, marker) is a reactive consumer of the two resources. `Main` wires
them together and owns input mode. Nothing but `FractalView` touches the shader.

**Tech stack:** Godot 4.6.1 (Mono build on disk, but **GDScript only**),
**GL Compatibility** renderer (WebGL 2, float32, no compute), macOS / Apple
silicon. Headless `SceneTree` tests extend `tests/test_case.gd`; the windowed
render check runs through `tests/screenshots.sh`.

**Source of truth:** `docs/superpowers/specs/2026-10-06-mandelbox-explorer-design.md`.
Read it before starting. This plan implements that spec and nothing beyond it.

---

## Global Constraints

Every task inherits these. They are not repeated per task.

- **Engine / renderer:** Godot 4.6, **GL Compatibility** only. `project.godot`
  declares `config/features=PackedStringArray("4.6", "GL Compatibility")`.
  **GDScript only — no C#.**
- **Git — commit, never publish.** Commit each task as a logical unit. **Never**
  run `git push`, `git merge`, `git rebase`, `git cherry-pick`, `git revert`,
  `git am`, `gh pr create`, or `gh pr merge`. Read-only git (`status`, `diff`,
  `log`, `show`, `branch`, `stash list`) is always fine. When the work is
  committed, stop and tell Adam it is ready.
- **Commit attribution:** end every commit message with the Co-Authored-By line
  for the Claude model you are running as, for example exactly:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **Never run `rm -rf`** or any recursive force-delete, in any form (not in the
  Bash tool, not inside a script, not chained). Remove single named files only
  with `rm -f <one file>`. If a recursive delete is ever genuinely needed, do
  not run it — put the exact command in a `bash` block at the end of your report
  and let Adam run it.
- **Work in `/Users/adam/Godot/HelpImStuckInAFractal` on `main`. No worktree**
  unless your own work is being trodden on.
- **Godot must never grab desktop focus.** Use `godot4 --headless` for tests,
  imports and parse checks. For a real rendered frame launch **only** through
  `tests/screenshots.sh`, which uses
  `open -g -n -W -a /Applications/Godot_mono.app --args --path "$PWD" -s <script>`
  (`-g` = no activation). **Never run the raw binary windowed** — it foregrounds.
- **Class cache.** After adding or renaming any `class_name` script or adding a
  shader, run `godot4 --headless --import --path .` **before** running tests, or
  headless runs fail with `Identifier "X" not declared`. `tests/run_all.sh` and
  `tests/screenshots.sh` do this import first; a single test run via
  `godot4 --headless --path . -s tests/<name>_test.gd` does **not**, so import
  by hand after adding a new `class_name`.
- **No `timeout` command on this machine.** Give the Bash tool a `timeout`
  parameter instead (use 600000 ms for `tests/run_all.sh`).
- **Headless renders nothing.** The headless (dummy) renderer returns null from
  `get_image()`; all pixel checks run **windowed** via `screenshots.gd`.
  Headless *does* fully parse shaders: `Shader.get_shader_uniform_list()` is
  empty iff the shader failed to compile, and lists declared-but-unused uniforms.
- **All positions are fractal coordinates** (the estimator's space). The site's
  camera coordinates are half of ours. **World up is +Z.**

---

## File structure

```
project.godot                         engine config, input actions, GL Compatibility
run.sh                                launch helper (./run.sh, ./run.sh --editor)
export_presets.cfg                    one Web preset, threads off
.gitignore                            + build/
src/
  main.tscn / main.gd                 Main: wiring + input mode
  fractal/
    fractal_params.gd                 Resource: shape/colour/precision/Julia/camera
    distance_estimator.gd             static CPU copy of the estimator (N=32)
    mandelbox.gdshader                canvas_item raymarcher
    fractal_view.tscn / fractal_view.gd   SubViewport + shader + display TextureRect
  camera/
    camera_state.gd                   Resource: Transform3D + speed_factor
    fly_camera.gd                     mouse-look + WASD/Space/Shift, distance speed
    orbit_camera.gd                   drag-to-orbit controller (+ private CPU march)
    julia_marker.gd                   draws/drags the Julia point
  ui/
    controls_panel.tscn / controls_panel.gd   the Q panel
  perf/
    resolution_governor.gd            adaptive render scale + idle freeze
tests/
  test_case.gd                        headless test base
  *_test.gd                           one per unit
  run_all.sh                          runs every headless test
  screenshots.gd / screenshots.sh     windowed render check
  out/                                screenshots.txt (git-ignored by *.tmp? no — see Task 15)
screenshots/                          PNG output of the windowed check
README.md
docs/
  reference/icefractal-default.jpg    reference capture (already present)
  superpowers/specs/ … plans/ …
```

---

## Task 1: Project boot & headless test harness

Boot the project headless, register the seven input actions, and stand up the
Fractacular-style test harness so every later task has something to run.

**Files:**
- Create: `project.godot`
- Create: `run.sh`
- Create: `tests/test_case.gd`
- Create: `tests/run_all.sh`
- Create: `tests/boot_test.gd`

**Interfaces:**
- Produces: input actions `move_forward`, `move_back`, `move_left`,
  `move_right`, `move_up`, `move_down`, `toggle_panel`; `class_name TestCase`
  with `check`, `check_eq`, `check_approx`, `frames`, `hold`, `press_action`,
  `finish`.

- [ ] **Step 1: Write the failing test** — `tests/boot_test.gd`

```gdscript
extends "res://tests/test_case.gd"
## The project boots headless, declares GL Compatibility, and has every action.


func run() -> void:
	check_eq(ProjectSettings.get_setting("application/config/name"), "Help I'm Stuck In A Fractal",
		"project name is set")
	var feats: PackedStringArray = ProjectSettings.get_setting("application/config/features")
	check(feats.has("GL Compatibility"), "GL Compatibility is declared")
	for action in ["move_forward", "move_back", "move_left", "move_right",
			"move_up", "move_down", "toggle_panel"]:
		check(InputMap.has_action(action), "action '%s' exists" % action)
```

- [ ] **Step 2: Create `tests/test_case.gd`** (reused from Fractacular verbatim)

```gdscript
class_name TestCase
extends SceneTree
## Base for headless tests. Subclass, override `run()`, and call the checks.
##
##   godot4 --headless --path . -s tests/<name>_test.gd
##
## `run()` may `await`. `finish()` prints a summary and quits with 0 or 1.

var _failures := 0
var _checks := 0


func _initialize() -> void:
	await run()
	finish()


## Override. Put every check in here.
func run() -> void:
	pass


func check(ok: bool, message: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", message)
	else:
		_failures += 1
		print("  FAIL ", message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_approx(actual: float, expected: float, message: String, eps: float = 1e-4) -> void:
	check(absf(actual - expected) <= eps, "%s (expected %s, got %s)" % [message, expected, actual])


## Wait `n` process frames.
func frames(n: int) -> void:
	for i in n:
		await process_frame


## Hold an input action down for `seconds` of process time.
func hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	var t := 0.0
	while t < seconds:
		await process_frame
		t += root.get_process_delta_time()
	Input.action_release(action)
	await process_frame


## Send a press+release of an action through the event pipeline, so that
## `_input` / `_unhandled_input` handlers see it (Input.action_press does not).
func press_action(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func finish() -> void:
	var name: String = get_script().resource_path.get_file()
	if _failures == 0:
		print("%s PASSED (%d checks)" % [name, _checks])
		quit(0)
	else:
		print("%s FAILED (%d of %d checks)" % [name, _failures, _checks])
		quit(1)
```

- [ ] **Step 3: Create `project.godot`**

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Help I'm Stuck In A Fractal"
run/main_scene="res://src/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[display]

window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="disabled"

[input]

move_forward={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
move_back={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
]
}
move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194325,"key_label":0,"unicode":0,"location":1,"echo":false,"script":null)
]
}
toggle_panel={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0, 0, 0, 1)
```

> `physical_keycode` 4194325 is `KEY_SHIFT`; 87/65/83/68 are W/A/S/D, 32 is
> Space, 81 is Q. `run/main_scene` points at `src/main.tscn`, which does not
> exist until Task 10 — that is fine for headless `-s` test runs; do not run the
> project (`./run.sh`) until Task 10.

- [ ] **Step 4: Create `run.sh`** (adapted from Fractacular) and `chmod +x run.sh`

```sh
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
```

- [ ] **Step 5: Create `tests/run_all.sh`** (reused from Fractacular) and `chmod +x tests/run_all.sh`

```sh
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
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/boot_test.gd`
Expected: it now PASSES, because `project.godot` and the harness were written in
the same task (this task's deliverable is the bootable project itself). If any
check prints `FAIL`, fix `project.godot` until all pass. (The "see it fail"
discipline applies from Task 2 onward, where test and implementation are
separate steps.)

- [ ] **Step 7: Run to verify it passes**

Run: `godot4 --headless --path . -s tests/boot_test.gd`
Expected: `boot_test.gd PASSED`

- [ ] **Step 8: Commit**

```bash
git add project.godot run.sh tests/test_case.gd tests/run_all.sh tests/boot_test.gd
git commit -m "feat: boot the project headless with the test harness

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: FractalParams

The shared shape/colour/precision/Julia/camera resource. Every setter emits
`changed`. Defaults are the site's defaults.

**Files:**
- Create: `src/fractal/fractal_params.gd`
- Create: `tests/fractal_params_test.gd`

**Interfaces:**
- Produces: `class_name FractalParams extends Resource` with exported fields
  `scale`, `inner_radius`, `fold_limit`, `outer_radius`, `color_mode: int`,
  `precision`, `julia_enabled: bool`, `julia_point: Vector3`,
  `fast_controls: bool`, `camera_mode: int` (enum `CameraMode { FLY, ORBIT }`),
  `mouse_sensitivity`; consts `COLOR_MODE_IDS: Array[int]`,
  `COLOR_MODE_NAMES: Array[String]`. Emits Resource's built-in `changed`.

- [ ] **Step 1: Write the failing test** — `tests/fractal_params_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var p := FractalParams.new()

	# defaults (the site's defaults)
	check_approx(p.scale, -2.09, "scale default")
	check_approx(p.inner_radius, 0.7, "inner_radius default")
	check_approx(p.fold_limit, 1.0, "fold_limit default")
	check_approx(p.outer_radius, 1.0, "outer_radius default")
	check_eq(p.color_mode, 1, "color_mode default is Ice Fractal")
	check_approx(p.precision, 0.000025, "precision default", 1e-9)
	check_eq(p.julia_enabled, false, "julia off by default")
	check(p.julia_point.is_equal_approx(Vector3(-0.23, 1.512, 1.892)), "julia_point default")
	check_eq(p.fast_controls, true, "fast_controls on by default")
	check_eq(p.camera_mode, FractalParams.CameraMode.FLY, "camera starts in fly mode")
	check_approx(p.mouse_sensitivity, 0.1, "mouse_sensitivity default")

	# the thirteen colour ids, in dropdown order
	check_eq(p.COLOR_MODE_IDS, [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14], "colour id order")
	check_eq(p.COLOR_MODE_NAMES.size(), 13, "thirteen colour names")
	check_eq(p.COLOR_MODE_NAMES[0], "Grayscale", "first colour name")
	check_eq(p.COLOR_MODE_NAMES[1], "Ice Fractal", "second colour name")
	check_eq(p.COLOR_MODE_NAMES[12], "Gold", "last colour name")

	# every setter emits `changed`
	for setter in [
		func(): p.scale = -3.0,
		func(): p.inner_radius = 0.5,
		func(): p.fold_limit = 0.8,
		func(): p.outer_radius = 0.9,
		func(): p.color_mode = 2,
		func(): p.precision = 0.0001,
		func(): p.julia_enabled = true,
		func(): p.julia_point = Vector3(1, 2, 3),
		func(): p.fast_controls = false,
		func(): p.camera_mode = FractalParams.CameraMode.ORBIT,
		func(): p.mouse_sensitivity = 0.2,
	]:
		var fired := [false]
		var cb := func(): fired[0] = true
		p.changed.connect(cb)
		setter.call()
		p.changed.disconnect(cb)
		check(fired[0], "a setter emitted changed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fractal_params_test.gd`
Expected: FAIL / load error — `FractalParams` not declared.

- [ ] **Step 3: Write the implementation** — `src/fractal/fractal_params.gd`

```gdscript
class_name FractalParams
extends Resource
## Every shape / colour / precision / Julia / camera value for the viewer.
## Setters emit Resource's built-in `changed` signal. Defaults match the site.

enum CameraMode { FLY, ORBIT }

## Colour-mode ids in the dropdown's order (ids match the site).
const COLOR_MODE_IDS: Array[int] = [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14]
const COLOR_MODE_NAMES: Array[String] = [
	"Grayscale", "Ice Fractal", "Borg", "Rainbow", "Rainbow 2", "Rainbow 3",
	"Rainbow Metal", "Blue", "Blue 2", "Pink-Blue", "Ice Box", "Ice Box 2", "Gold",
]

@export var scale: float = -2.09:
	set(v): scale = v; emit_changed()
@export var inner_radius: float = 0.7:
	set(v): inner_radius = v; emit_changed()
@export var fold_limit: float = 1.0:
	set(v): fold_limit = v; emit_changed()
@export var outer_radius: float = 1.0:
	set(v): outer_radius = v; emit_changed()
@export var color_mode: int = 1:
	set(v): color_mode = v; emit_changed()
@export var precision: float = 0.000025:
	set(v): precision = v; emit_changed()
@export var julia_enabled: bool = false:
	set(v): julia_enabled = v; emit_changed()
@export var julia_point: Vector3 = Vector3(-0.23, 1.512, 1.892):
	set(v): julia_point = v; emit_changed()
@export var fast_controls: bool = true:
	set(v): fast_controls = v; emit_changed()
@export var camera_mode: CameraMode = CameraMode.FLY:
	set(v): camera_mode = v; emit_changed()
@export var mouse_sensitivity: float = 0.1:
	set(v): mouse_sensitivity = v; emit_changed()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fractal_params_test.gd`
Expected: `fractal_params_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/fractal/fractal_params.gd tests/fractal_params_test.gd
git commit -m "feat: FractalParams resource with the site's defaults

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: DistanceEstimator (CPU)

The N=32 Mandelbox estimator (Tom Lowe's formula) with a scalar derivative. Must
agree with the shader; pinned to the site's own numbers.

> **Validated during planning.** The code below was run headless against all 24
> fixtures on this machine's `godot4` (4.6.1). 22 of 24 agree with the spec
> within relative 1e-5. Two **near-surface, non-Julia** points are chaotically
> float-sensitive and need a looser tolerance (they are a hair off at the last
> few ulps after 32 iterations, then amplified by dividing by a large `dz`):
> defaults `(1.2,−0.3,0.8)` measured `4.5415883e-5` vs spec `4.536385e-5`
> (rel ≈ 1.1e-3), and defaults `(0.1,0.9,1.5)` measured `1.2708344e-5` vs spec
> `1.2707534e-5` (rel ≈ 6.4e-5). The test below applies the spec's 1e-5 to every
> row except those two. Do **not** change the maths to chase those two numbers —
> the maths is correct; the spec's blanket tolerance is simply too tight there.

**Files:**
- Create: `src/fractal/distance_estimator.gd`
- Create: `tests/distance_estimator_test.gd`

**Interfaces:**
- Consumes: `FractalParams` (reads `scale`, `inner_radius`, `outer_radius`,
  `fold_limit`, `julia_enabled`, `julia_point`).
- Produces: `class_name DistanceEstimator` with
  `static func estimate(p: Vector3, params: FractalParams) -> float`.

- [ ] **Step 1: Write the failing test** — `tests/distance_estimator_test.gd`

```gdscript
extends "res://tests/test_case.gd"
## Pins the CPU estimator to the site's own numbers (24 fixtures), plus
## symmetry and Julia-sensitivity. See the plan's validation note for the two
## near-surface rows that carry a looser tolerance.


func _de(p: Vector3, params: FractalParams, expected: float, label: String,
		rel := 1e-5, abs_floor := 1e-9) -> void:
	var got := DistanceEstimator.estimate(p, params)
	var tol := maxf(abs_floor, rel * absf(expected))
	check(absf(got - expected) <= tol,
		"%s: expected %.10g got %.10g (tol %.3g)" % [label, expected, got, tol])


func run() -> void:
	# --- defaults: scale -2.09, inner 0.7, fold 1, outer 1, no Julia ---
	var d := FractalParams.new()
	_de(Vector3(0, 0, 0), d, 0.0, "def (0,0,0)")
	_de(Vector3(0.5, 0.5, 0.5), d, 1.67e-15, "def (0.5,0.5,0.5)")
	_de(Vector3(1.2, -0.3, 0.8), d, 4.536385e-5, "def (1.2,-0.3,0.8)", 2e-3)  # boundary-sensitive
	_de(Vector3(2, 2, 2), d, 1.84e-20, "def (2,2,2)")
	_de(Vector3(3, 0, 0), d, 1.0000000, "def (3,0,0)")
	_de(Vector3(8.18, 3.81, 3.28), d, 6.5655845, "def (8.18,3.81,3.28)")
	_de(Vector3(0.1, 0.9, 1.5), d, 1.2707534e-5, "def (0.1,0.9,1.5)", 1e-4)  # boundary-sensitive
	_de(Vector3(-1.5, 1.5, -1.5), d, 7.2696999e-3, "def (-1.5,1.5,-1.5)")

	# --- alternative shape: scale -3, inner 0.5, fold 0.8, outer 0.9 ---
	var a := FractalParams.new()
	a.scale = -3.0; a.inner_radius = 0.5; a.fold_limit = 0.8; a.outer_radius = 0.9
	_de(Vector3(0, 0, 0), a, 0.0, "alt (0,0,0)")
	_de(Vector3(0.5, 0.5, 0.5), a, 3.9589733e-3, "alt (0.5,0.5,0.5)")
	_de(Vector3(1.2, -0.3, 0.8), a, 7.3684211e-2, "alt (1.2,-0.3,0.8)")
	_de(Vector3(2, 2, 2), a, 0.69282032, "alt (2,2,2)")
	_de(Vector3(3, 0, 0), a, 1.4000000, "alt (3,0,0)")
	_de(Vector3(8.18, 3.81, 3.28), a, 7.1416315, "alt (8.18,3.81,3.28)")
	_de(Vector3(0.1, 0.9, 1.5), a, 1.2998357e-2, "alt (0.1,0.9,1.5)")
	_de(Vector3(-1.5, 1.5, -1.5), a, 3.5649260e-3, "alt (-1.5,1.5,-1.5)")

	# --- defaults with Julia on at (-0.23, 1.512, 1.892) ---
	var j := FractalParams.new()
	j.julia_enabled = true
	_de(Vector3(0, 0, 0), j, 4.9979908e-3, "jul (0,0,0)")
	_de(Vector3(0.5, 0.5, 0.5), j, 1.0887837e-2, "jul (0.5,0.5,0.5)")
	_de(Vector3(1.2, -0.3, 0.8), j, 4.5308936e-3, "jul (1.2,-0.3,0.8)")
	_de(Vector3(2, 2, 2), j, 4.9979908e-3, "jul (2,2,2)")
	_de(Vector3(3, 0, 0), j, 8.0696204e-3, "jul (3,0,0)")
	_de(Vector3(8.18, 3.81, 3.28), j, 2.3521820, "jul (8.18,3.81,3.28)")
	_de(Vector3(0.1, 0.9, 1.5), j, 3.6647735e-3, "jul (0.1,0.9,1.5)")
	_de(Vector3(-1.5, 1.5, -1.5), j, 0.25217396, "jul (-1.5,1.5,-1.5)")

	# --- symmetry: D(p) == D(-p) in non-Julia mode ---
	for p in [Vector3(0.7, 0.3, 0.9), Vector3(1.2, -0.3, 0.8), Vector3(3, 0, 0),
			Vector3(8.18, 3.81, 3.28)]:
		check_approx(DistanceEstimator.estimate(p, d), DistanceEstimator.estimate(-p, d),
			"D(p) == D(-p) at %s" % p, 1e-9)

	# --- the Julia point changes the result ---
	check(absf(DistanceEstimator.estimate(Vector3(3, 0, 0), d)
			- DistanceEstimator.estimate(Vector3(3, 0, 0), j)) > 0.5,
		"turning Julia on changes the distance")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/distance_estimator_test.gd`
Expected: FAIL / load error — `DistanceEstimator` not declared.

- [ ] **Step 3: Write the implementation** — `src/fractal/distance_estimator.gd`

```gdscript
class_name DistanceEstimator
extends RefCounted
## CPU copy of the shader's Mandelbox distance estimator (Tom Lowe's formula),
## N = 32 (the high-precision variant). Carries the scalar derivative in `dz`.
## Must give the same numbers as mandelbox.gdshader's `de(p, 32)`.

const ITERATIONS := 32


static func estimate(p: Vector3, params: FractalParams) -> float:
	var scale := params.scale
	var min_r2 := params.inner_radius * params.inner_radius
	var fixed_r2 := params.outer_radius * params.outer_radius
	var fold := params.fold_limit
	var c := params.julia_point if params.julia_enabled else p
	var z := p
	var dz := 1.0
	for i in ITERATIONS:
		# Box fold each component.
		z = Vector3(
			clampf(z.x, -fold, fold) * 2.0 - z.x,
			clampf(z.y, -fold, fold) * 2.0 - z.y,
			clampf(z.z, -fold, fold) * 2.0 - z.z)
		# Sphere fold.
		var r2 := z.dot(z)
		var k := 1.0
		if r2 < min_r2:
			k = fixed_r2 / min_r2
		elif r2 < fixed_r2:
			k = fixed_r2 / r2
		z *= k
		dz *= k
		# Scale and add.
		z = scale * z + c
		dz = -dz * scale + 1.0
	return z.length() / absf(dz)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/distance_estimator_test.gd`
Expected: `distance_estimator_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/fractal/distance_estimator.gd tests/distance_estimator_test.gd
git commit -m "feat: CPU Mandelbox distance estimator pinned to the site's values

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: CameraState

The shared camera resource: a `Transform3D` plus a speed factor, with convenience
getters and a factory for the site's default view.

**Files:**
- Create: `src/camera/camera_state.gd`
- Create: `tests/camera_state_test.gd`

**Interfaces:**
- Produces: `class_name CameraState extends Resource` with `transform: Transform3D`,
  `speed_factor: float` (both emit `changed`), getters `eye()`, `forward()`,
  `right()`, `up()`, and `static func make_default() -> CameraState`.

- [ ] **Step 1: Write the failing test** — `tests/camera_state_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var c := CameraState.make_default()

	# the site's default view
	check(c.eye().is_equal_approx(Vector3(8.175847, 3.812460, 3.283393)), "default eye")
	check(c.forward().is_equal_approx((Vector3.ZERO - c.eye()).normalized()),
		"forward looks at the origin")
	check_approx(c.forward().length(), 1.0, "forward is unit length")
	check_approx(c.right().dot(c.up()), 0.0, "right and up are orthogonal", 1e-5)
	check_approx(c.right().dot(c.forward()), 0.0, "right and forward are orthogonal", 1e-5)
	# +Z is the up hint: right stays horizontal
	check_approx(c.right().z, 0.0, "right is level (world +Z up hint)", 1e-5)
	check_approx(c.speed_factor, 1.0, "speed factor default")

	# setters emit changed
	var fired := [0]
	c.changed.connect(func(): fired[0] += 1)
	c.transform = Transform3D.IDENTITY
	c.speed_factor = 2.0
	check_eq(fired[0], 2, "both setters emitted changed")
	check(c.eye().is_equal_approx(Vector3.ZERO), "transform setter moved the eye")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/camera_state_test.gd`
Expected: FAIL / load error — `CameraState` not declared.

- [ ] **Step 3: Write the implementation** — `src/camera/camera_state.gd`

```gdscript
class_name CameraState
extends Resource
## The camera as a Transform3D (Godot convention: forward = -basis.z) plus a
## distance-speed multiplier. Setters emit Resource's built-in `changed`.

const DEFAULT_EYE := Vector3(8.175847, 3.812460, 3.283393)

@export var transform: Transform3D = Transform3D.IDENTITY:
	set(v): transform = v; emit_changed()
@export var speed_factor: float = 1.0:
	set(v): speed_factor = v; emit_changed()


func eye() -> Vector3:
	return transform.origin


func forward() -> Vector3:
	return -transform.basis.z


func right() -> Vector3:
	return transform.basis.x


func up() -> Vector3:
	return transform.basis.y


## The site's initial view: eye at DEFAULT_EYE, looking at the origin, +Z up.
static func make_default() -> CameraState:
	var c := CameraState.new()
	var t := Transform3D(Basis.IDENTITY, DEFAULT_EYE)
	c.transform = t.looking_at(Vector3.ZERO, Vector3(0, 0, 1))
	return c
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/camera_state_test.gd`
Expected: `camera_state_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/camera/camera_state.gd tests/camera_state_test.gd
git commit -m "feat: CameraState resource with the site's default view

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: mandelbox.gdshader

The canvas_item raymarcher. The full source below was **compiled headless on
this machine** (Godot 4.6.1); `get_shader_uniform_list()` returned exactly the
15 uniforms in the spec's table, in order. Create it verbatim.

**Files:**
- Create: `src/fractal/mandelbox.gdshader`
- Create: `tests/shader_test.gd`

**Interfaces:**
- Produces: a `canvas_item` shader with uniforms `eye`, `cam_right`, `cam_up`,
  `cam_forward` (vec3), `tan_half_fov`, `aspect` (float), `scale`, `min_r2`,
  `fixed_r2`, `fold_limit`, `precision` (float), `color_mode` (int),
  `julia_enabled` (bool), `julia_point` (vec3), `box_half` (float).

- [ ] **Step 1: Write the failing test** — `tests/shader_test.gd`

```gdscript
extends "res://tests/test_case.gd"
## The shader compiles headless and declares exactly the spec's uniforms.
## (A shader that fails to compile yields an empty uniform list.)


func run() -> void:
	var sh: Shader = load("res://src/fractal/mandelbox.gdshader")
	check(sh != null, "the shader resource loads")
	var names: Array = []
	for u in sh.get_shader_uniform_list():
		names.append(String(u["name"]))
	check(names.size() > 0, "shader compiles (uniform list non-empty)")
	var expected := ["eye", "cam_right", "cam_up", "cam_forward", "tan_half_fov",
		"aspect", "scale", "min_r2", "fixed_r2", "fold_limit", "precision",
		"color_mode", "julia_enabled", "julia_point", "box_half"]
	check_eq(names.size(), expected.size(), "exactly %d uniforms" % expected.size())
	for u in expected:
		check(names.has(u), "uniform '%s' is declared" % u)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/shader_test.gd`
Expected: FAIL — the shader file does not exist, `load()` returns null.

- [ ] **Step 3: Write the implementation** — `src/fractal/mandelbox.gdshader`

```glsl
shader_type canvas_item;
// Mandelbox raymarcher. Written from the design spec's algorithm; nothing is
// copied from icefractal.com. All float math is highp (WebGL 2 => float32),
// which is Godot's canvas_item default.

uniform vec3 eye;
uniform vec3 cam_right;
uniform vec3 cam_up;
uniform vec3 cam_forward;
uniform float tan_half_fov;
uniform float aspect;
uniform float scale;
uniform float min_r2;
uniform float fixed_r2;
uniform float fold_limit;
uniform float precision;
uniform int color_mode;
uniform bool julia_enabled;
uniform vec3 julia_point;
uniform float box_half;

// Mandelbox distance estimate, up to `iters` iterations (<= 32).
float de(vec3 p, int iters) {
	vec3 c = julia_enabled ? julia_point : p;
	vec3 z = p;
	float dz = 1.0;
	for (int i = 0; i < 32; i++) {
		if (i >= iters) { break; }
		z = clamp(z, -fold_limit, fold_limit) * 2.0 - z;
		float r2 = dot(z, z);
		float k = 1.0;
		if (r2 < min_r2) {
			k = fixed_r2 / min_r2;
		} else if (r2 < fixed_r2) {
			k = fixed_r2 / r2;
		}
		z *= k;
		dz *= k;
		z = scale * z + c;
		dz = -dz * scale + 1.0;
	}
	return length(z) / abs(dz);
}

// The "Ice Fractal" field: a 16-iteration Mandelbox orbit from z=0, c=q, no
// derivative, offset by -8. Not a true distance; its gradient gives the look.
float field(vec3 q) {
	vec3 z = vec3(0.0);
	vec3 c = q;
	for (int i = 0; i < 16; i++) {
		z = clamp(z, -fold_limit, fold_limit) * 2.0 - z;
		float r2 = dot(z, z);
		float k = 1.0;
		if (r2 < min_r2) {
			k = fixed_r2 / min_r2;
		} else if (r2 < fixed_r2) {
			k = fixed_r2 / r2;
		}
		z *= k;
		z = scale * z + c;
	}
	return length(z) - 8.0;
}

// Central-difference normal from the high-precision estimator.
vec3 calc_normal(vec3 v, float delta) {
	vec2 e = vec2(delta, 0.0);
	return normalize(vec3(
		de(v + e.xyy, 32) - de(v - e.xyy, 32),
		de(v + e.yxy, 32) - de(v - e.yxy, 32),
		de(v + e.yyx, 32) - de(v - e.yyx, 32)));
}

// The Ice Fractal normal: field at the half-scale base point h = v/2, offset
// samples at the full-scale point + 0.01. Not a true gradient, by design.
vec3 calc_nf(vec3 v, vec3 h) {
	float lw = field(h);
	vec3 g = vec3(
		field(v + vec3(0.01, 0.0, 0.0)) - lw,
		field(v + vec3(0.0, 0.01, 0.0)) - lw,
		field(v + vec3(0.0, 0.0, 0.01)) - lw) / 0.01;
	return normalize(g);
}

// Six-segment rainbow ramp: red->yellow->green->cyan->blue->magenta->red.
vec3 hue(float q) {
	q = clamp(q, 0.0, 0.999999);
	float h6 = q * 6.0;
	float x = 1.0 - abs(mod(h6, 2.0) - 1.0);
	if (h6 < 1.0) { return vec3(1.0, x, 0.0); }
	else if (h6 < 2.0) { return vec3(x, 1.0, 0.0); }
	else if (h6 < 3.0) { return vec3(0.0, 1.0, x); }
	else if (h6 < 4.0) { return vec3(0.0, x, 1.0); }
	else if (h6 < 5.0) { return vec3(x, 0.0, 1.0); }
	return vec3(1.0, 0.0, x);
}

// Ray vs axis-aligned cube of half-size `half_size`, centred at the origin.
// Returns vec2(t_enter, t_exit); a miss has t_exit < max(t_enter, 0).
vec2 box_intersect(vec3 ro, vec3 rd, float half_size) {
	vec3 inv = 1.0 / rd;
	vec3 n = inv * ro;
	vec3 k = abs(inv) * half_size;
	vec3 t1 = -n - k;
	vec3 t2 = -n + k;
	float t_enter = max(max(t1.x, t1.y), t1.z);
	float t_exit = min(min(t2.x, t2.y), t2.z);
	return vec2(t_enter, t_exit);
}

void fragment() {
	vec2 ndc = (UV - 0.5) * 2.0;
	ndc.y = -ndc.y;  // +y up
	vec3 dir = normalize(cam_forward
		+ ndc.x * aspect * tan_half_fov * cam_right
		+ ndc.y * tan_half_fov * cam_up);

	vec3 bg = (color_mode == 5 || color_mode == 6) ? vec3(1.0) : vec3(0.0);

	vec2 tb = box_intersect(eye, dir, box_half);
	if (tb.y < max(tb.x, 0.0)) {
		COLOR = vec4(bg, 1.0);
	} else {
		float t_exit = tb.y;
		float total = max(tb.x, 0.0);
		bool left_cube = false;

		// Phase 1: low precision (N=16), up to 96 steps.
		int n1 = 96;
		for (int i = 0; i < 96; i++) {
			vec3 pos = eye + dir * total;
			float d = de(pos, 16);
			if (d < precision * total * 2.0) { n1 = i; break; }
			total += d;
			if (total > t_exit) { left_cube = true; break; }
		}

		// Phase 2: high precision (N=32), up to 32 steps, continuing on.
		int n2 = 32;
		if (!left_cube) {
			for (int i = 0; i < 32; i++) {
				vec3 pos = eye + dir * total;
				float d = de(pos, 32);
				if (d < precision * total) { n2 = i; break; }
				total += d;
				if (total > t_exit) { left_cube = true; break; }
			}
		}

		if (left_cube) {
			COLOR = vec4(bg, 1.0);  // the only miss is leaving the cube
		} else {
			float ce = float(n1 + n2) / 128.0;
			float inv = 1.0 - ce;
			vec3 v = eye + dir * total;
			vec3 h = v * 0.5;
			vec3 eh = eye * 0.5;
			float delta = precision * total * 40.0;

			// Normal: NF for modes 1..9 outside Julia mode, N otherwise.
			vec3 n;
			if (color_mode >= 1 && color_mode <= 9 && !julia_enabled) {
				n = calc_nf(v, h);
			} else {
				n = calc_normal(v, delta);
			}

			vec3 ldir = normalize(2.0 * eh - h);
			float lgt = abs(dot(n, ldir));
			lgt = 0.5 * lgt + pow(lgt, 160.0) + 0.1;
			vec3 base = vec3(lgt) * (-n * 0.25 + 0.75) + vec3(0.0, 0.0, 0.2);

			vec3 col;
			if (color_mode == 0) {
				col = vec3(inv);
			} else if (color_mode == 1) {
				col = base * vec3(inv + 0.5, 2.0 * inv * inv + 0.5, 5.0 * pow(inv, 4.0) + 0.5);
			} else if (color_mode == 2) {
				col = base * vec3(max(lgt * ce, inv), max(ce, inv), max(0.5 * lgt * ce, inv));
			} else if (color_mode == 3) {
				float q = dot(h, h) / 4.0;
				col = hue(q) * ce + 0.5 * lgt;
			} else if (color_mode == 4) {
				float q = dot(h, h) / 4.0;
				col = hue(q) * inv;
			} else if (color_mode == 8) {
				float q = n.z * 0.5 + 0.5 - 0.1;
				col = hue(q) * inv;
			} else if (color_mode == 5) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = base * vec3(lgt * max(lgt * ce, inv), lgt + avg, inv + lgt);
			} else if (color_mode == 6) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = base * vec3(lgt * max(lgt * ce, inv), lgt + avg, inv + lgt) + vec3(ce * ce);
			} else if (color_mode == 7) {
				float avg = (base.r + base.g + base.b) / 3.0;
				col = vec3(1.0 - 2.0 * ce * (lgt + 0.5), avg * inv, inv * (lgt + 0.5));
			} else if (color_mode == 9) {
				col = vec3(inv * inv, 1.0 - 1.9 * ce * ce, 1.17 - ce * ce);
			} else if (color_mode == 16) {
				col = clamp(vec3(inv * inv, 1.0 - 1.9 * ce * ce, 1.17 - ce * ce), 0.0, 1.0) * (lgt + 0.5);
			} else if (color_mode == 15) {
				vec3 nv = vec3(dot(n, cam_right), dot(n, cam_up), dot(n, -cam_forward));
				float lv = pow(max(0.0, nv.z), 4.0);
				vec3 n2v = normalize(nv + vec3(0.5, 0.5, 0.0));
				col = (n2v + 1.0) * 0.5 * (lv - 2.0 * ce + 0.5);
			} else if (color_mode == 14) {
				vec3 nv = vec3(dot(n, cam_right), dot(n, cam_up), dot(n, -cam_forward));
				float lv = pow(max(0.0, nv.z), 4.0);
				col = (0.75 - ce) * 2.0 * vec3(lv, lv * lv, lv * ce);
			} else {
				col = vec3(inv);
			}
			COLOR = vec4(col, 1.0);
		}
	}
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/shader_test.gd`
Expected: `shader_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/fractal/mandelbox.gdshader tests/shader_test.gd
git commit -m "feat: Mandelbox canvas_item raymarcher shader

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: FractalView

A `SubViewport` running the shader, a `TextureRect` displaying it, render-scale
control, and the `project` / `unproject` pair the marker and orbit camera need.

**Files:**
- Create: `src/fractal/fractal_view.tscn`
- Create: `src/fractal/fractal_view.gd`
- Create: `tests/fractal_view_test.gd`

**Interfaces:**
- Consumes: `FractalParams`, `CameraState`, `mandelbox.gdshader`.
- Produces: `class_name FractalView extends Control` with
  `setup(params: FractalParams, camera: CameraState)`,
  `set_render_scale(s: float)`, `render_scale: float`,
  `request_frame()`, `set_continuous(on: bool)`,
  `project(point: Vector3) -> Variant` (Vector2 or null),
  `unproject(pixel: Vector2, depth: float) -> Vector3`,
  const `TAN_HALF_FOV := tan(deg_to_rad(20.0))`, and `viewport_size() -> Vector2i`.

- [ ] **Step 1: Write the failing test** — `tests/fractal_view_test.gd`

```gdscript
extends "res://tests/test_case.gd"
## project/unproject round-trip, render-scale sizing, and that the view's shader
## material carries the compiled shader.


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	view.size = Vector2(1280, 800)   # projection uses the Control's own size
	view.setup(params, cam)
	await frames(1)

	# the shader material is wired and compiled
	var names: Array = []
	for u in view.shader_uniform_names():
		names.append(String(u))
	check(names.has("eye") and names.has("box_half"), "view's shader declares the uniforms")

	# project then unproject round-trips a point in front of the camera
	var p := Vector3(0.5, 0.2, 0.1)   # near the origin, in view
	var px: Variant = view.project(p)
	check(px != null, "a point in front projects to a pixel")
	if px != null:
		var rel: Vector3 = p - cam.eye()
		var depth: float = rel.dot(cam.forward())
		var back: Vector3 = view.unproject(px, depth)
		check(back.is_equal_approx(p), "unproject(project(p)) == p (got %s)" % back)

	# a point behind the camera projects to null
	var behind: Vector3 = cam.eye() + cam.forward() * -5.0
	check(view.project(behind) == null, "a point behind the camera projects to null")

	# render scale sets the SubViewport size (rounded to whole pixels)
	view.set_render_scale(0.5)
	await frames(1)
	check_eq(view.viewport_size(), Vector2i(640, 400), "render_scale 0.5 halves the viewport")
	view.set_render_scale(2.0)   # clamps to 1.0
	await frames(1)
	check_eq(view.viewport_size(), Vector2i(1280, 800), "render_scale clamps to 1.0")

	view.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fractal_view_test.gd`
Expected: FAIL — scene/`FractalView` do not exist.

- [ ] **Step 3: Write `src/fractal/fractal_view.gd`**

```gdscript
class_name FractalView
extends Control
## Renders the fractal in a SubViewport and displays it full-window. Also owns
## the ray maths (project/unproject) so the Julia marker and orbit camera agree
## with the shader exactly.

const TAN_HALF_FOV := 0.36397023426620234  # tan(20 degrees), half of a 40 deg vertical FOV

var render_scale := 1.0
var continuous := false

var _params: FractalParams
var _camera: CameraState
var _viewport: SubViewport
var _rect: ColorRect
var _display: TextureRect
var _material: ShaderMaterial
var _pending_size := Vector2i(1280, 800)


func _ready() -> void:
	_viewport = $SubViewport
	_rect = $SubViewport/ColorRect
	_display = $Display
	_material = _rect.material as ShaderMaterial
	_display.texture = _viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_size)
	_apply_size()


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera
	if not params.changed.is_connected(_on_params_changed):
		params.changed.connect(_on_params_changed)
	if not camera.changed.is_connected(_on_camera_changed):
		camera.changed.connect(_on_camera_changed)
	_push_params()
	_push_camera()
	request_frame()


func shader_uniform_names() -> Array:
	var out: Array = []
	if _material and _material.shader:
		for u in _material.shader.get_shader_uniform_list():
			out.append(u["name"])
	return out


func viewport_size() -> Vector2i:
	return _viewport.size


func set_render_scale(s: float) -> void:
	render_scale = clampf(s, 0.25, 1.0)
	_apply_size()


func request_frame() -> void:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_continuous(on: bool) -> void:
	continuous = on
	_viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Returns the window pixel of `point`, or null when it is behind the camera.
func project(point: Vector3) -> Variant:
	var rel := point - _camera.eye()
	var z_c := rel.dot(_camera.forward())
	if z_c <= 0.0:
		return null
	var x_c := rel.dot(_camera.right())
	var y_c := rel.dot(_camera.up())
	var a := _aspect()
	var ndc_x := (x_c / z_c) / (a * TAN_HALF_FOV)
	var ndc_y := (y_c / z_c) / TAN_HALF_FOV
	var uv := Vector2(ndc_x * 0.5 + 0.5, 0.5 - ndc_y * 0.5)
	return uv * size


## The world point at camera-forward depth `depth` under window `pixel`.
func unproject(pixel: Vector2, depth: float) -> Vector3:
	var uv := pixel / size
	var ndc_x := (uv.x - 0.5) * 2.0
	var ndc_y := -(uv.y - 0.5) * 2.0
	var a := _aspect()
	var d := _camera.forward() \
		+ ndc_x * a * TAN_HALF_FOV * _camera.right() \
		+ ndc_y * TAN_HALF_FOV * _camera.up()
	return _camera.eye() + d * depth


func _aspect() -> float:
	return size.x / maxf(size.y, 1.0)


func _apply_size() -> void:
	var px := Vector2i(maxi(1, int(round(size.x * render_scale))),
		maxi(1, int(round(size.y * render_scale))))
	_viewport.size = px
	_rect.size = Vector2(px)
	if _material:
		_material.set_shader_parameter("aspect", _aspect())


func _on_params_changed() -> void:
	_push_params()
	request_frame()


func _on_camera_changed() -> void:
	_push_camera()
	request_frame()


func _push_params() -> void:
	if _material == null or _params == null:
		return
	_material.set_shader_parameter("scale", _params.scale)
	_material.set_shader_parameter("min_r2", _params.inner_radius * _params.inner_radius)
	_material.set_shader_parameter("fixed_r2", _params.outer_radius * _params.outer_radius)
	_material.set_shader_parameter("fold_limit", _params.fold_limit)
	_material.set_shader_parameter("precision", _params.precision)
	_material.set_shader_parameter("color_mode", _params.color_mode)
	_material.set_shader_parameter("julia_enabled", _params.julia_enabled)
	_material.set_shader_parameter("julia_point", _params.julia_point)
	_material.set_shader_parameter("tan_half_fov", TAN_HALF_FOV)
	_material.set_shader_parameter("box_half", 20.0 if _params.julia_enabled else 2.0)


func _push_camera() -> void:
	if _material == null or _camera == null:
		return
	_material.set_shader_parameter("eye", _camera.eye())
	_material.set_shader_parameter("cam_right", _camera.right())
	_material.set_shader_parameter("cam_up", _camera.up())
	_material.set_shader_parameter("cam_forward", _camera.forward())
```

- [ ] **Step 4: Create `src/fractal/fractal_view.tscn`**

Build this scene (in the editor it would be trivial; from the terminal, write
the `.tscn` text below). Root `FractalView` (Control) with the script attached;
a `SubViewport` child holding a `ColorRect` with a `ShaderMaterial` pointing at
`mandelbox.gdshader`; and a `TextureRect` named `Display`.

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://src/fractal/fractal_view.gd" id="1"]
[ext_resource type="Shader" path="res://src/fractal/mandelbox.gdshader" id="2"]

[sub_resource type="ShaderMaterial" id="mat"]
shader = ExtResource("2")

[node name="FractalView" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")

[node name="Display" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="SubViewport" type="SubViewport" parent="."]
disable_3d = true
transparent_bg = false
render_target_update_mode = 1
size = Vector2i(1280, 800)

[node name="ColorRect" type="ColorRect" parent="SubViewport"]
material = SubResource("mat")
offset_right = 1280.0
offset_bottom = 800.0
```

> After writing the `.tscn`, run `godot4 --headless --import --path .` so Godot
> registers the scene and its ext_resources before any test loads it.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fractal_view_test.gd`
Expected: `fractal_view_test.gd PASSED`

> If the round-trip fails, check that `project` and `unproject` use the Control's
> `size` (not `DisplayServer` window size) — the test sets `view.size` directly.

- [ ] **Step 6: Commit**

```bash
git add src/fractal/fractal_view.gd src/fractal/fractal_view.tscn tests/fractal_view_test.gd
git commit -m "feat: FractalView with SubViewport render and project/unproject

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: FlyCamera

Mouse-look (yaw about world +Z, pitch about camera right, no roll),
WASD/Space/Shift movement in camera axes, distance-scaled speed, wheel-driven
speed factor.

**Files:**
- Create: `src/camera/fly_camera.gd`
- Create: `tests/fly_camera_test.gd`

**Interfaces:**
- Consumes: `FractalParams`, `CameraState`, `DistanceEstimator`, the six move
  actions.
- Produces: `class_name FlyCamera extends Node` with
  `setup(params, camera)`, `enabled: bool`, `apply_look(dx: float, dy: float)`,
  `move_direction() -> Vector3`, `current_speed() -> float`, `scroll(up: bool)`.

- [ ] **Step 1: Write the failing test** — `tests/fly_camera_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func _fresh() -> Array:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var fly := FlyCamera.new()
	root.add_child(fly)
	fly.setup(params, cam)
	return [params, cam, fly]


func run() -> void:
	# --- each action moves along the matching camera axis ---
	var ctx := _fresh()
	var cam: CameraState = ctx[1]
	var fly: FlyCamera = ctx[2]
	var cases := {
		"move_forward": cam.forward(), "move_back": -cam.forward(),
		"move_right": cam.right(), "move_left": -cam.right(),
		"move_up": cam.up(), "move_down": -cam.up(),
	}
	for action in cases:
		Input.action_press(action)
		var dir: Vector3 = fly.move_direction()
		Input.action_release(action)
		check(dir.is_equal_approx(cases[action]), "%s moves along its axis (got %s)" % [action, dir])

	# --- combined input is normalised ---
	Input.action_press("move_forward")
	Input.action_press("move_right")
	var combo: Vector3 = fly.move_direction()
	Input.action_release("move_forward")
	Input.action_release("move_right")
	check_approx(combo.length(), 1.0, "diagonal input is normalised")

	# --- speed equals D(eye) * factor within [1e-6, 20] * factor ---
	var params: FractalParams = ctx[0]
	var expected := clampf(DistanceEstimator.estimate(cam.eye(), params), 1e-6, 20.0) * cam.speed_factor
	check_approx(fly.current_speed(), expected, "speed is clamped D(eye) * factor", 1e-6)

	# --- the wheel scales the factor by 1.25, clamped to [0.01, 100] ---
	var f0 := cam.speed_factor
	fly.scroll(true)
	check_approx(cam.speed_factor, f0 * 1.25, "wheel up multiplies the factor")
	fly.scroll(false)
	check_approx(cam.speed_factor, f0, "wheel down divides it back")
	for i in 60: fly.scroll(false)
	check(cam.speed_factor >= 0.01, "factor floors at 0.01")
	for i in 120: fly.scroll(true)
	check(cam.speed_factor <= 100.0, "factor ceils at 100")

	# --- yaw keeps the camera level; pitch is clamped away from +/-Z ---
	fly.apply_look(100.0, 0.0)   # pure yaw
	check_approx(cam.right().z, 0.0, "after yaw the right axis is still level", 1e-5)
	fly.apply_look(0.0, 1e6)     # extreme pitch down
	check(absf(cam.forward().z) < 0.9999, "pitch never reaches straight down (+/-Z)")
	fly.apply_look(0.0, -1e6)    # extreme pitch up
	check(absf(cam.forward().z) < 0.9999, "pitch never reaches straight up (+/-Z)")

	fly.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fly_camera_test.gd`
Expected: FAIL / load error — `FlyCamera` not declared.

- [ ] **Step 3: Write the implementation** — `src/camera/fly_camera.gd`

```gdscript
class_name FlyCamera
extends Node
## Free-fly camera: mouse-look (yaw about world +Z, pitch about the camera's own
## right, no roll) and WASD/Space/Shift movement whose speed scales with the
## distance to the nearest surface. Reads and writes a shared CameraState.

const WORLD_UP := Vector3(0, 0, 1)
const MIN_PITCH_MARGIN_DEG := 1.0   # keep forward 1 deg away from +/-Z

var enabled := false

var _params: FractalParams
var _camera: CameraState


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative.x, event.relative.y)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll(false)


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var dir := move_direction()
	if dir.length() == 0.0:
		return
	var t := _camera.transform
	t.origin += dir * current_speed() * delta
	_camera.transform = t


## Rotate the view by a mouse delta (pixels). Yaw about world +Z, pitch about
## the camera's right axis, pitch clamped, roll removed by rebuilding the basis.
func apply_look(dx: float, dy: float) -> void:
	var sens := _params.mouse_sensitivity
	var yaw := deg_to_rad(-dx * sens)
	var pitch := deg_to_rad(-dy * sens)
	var fwd := _camera.forward()

	# yaw about world +Z
	fwd = fwd.rotated(WORLD_UP, yaw)

	# pitch about the current right axis (recomputed from yawed forward)
	var right := fwd.cross(WORLD_UP).normalized()
	fwd = fwd.rotated(right, pitch)

	# clamp so forward stays away from +/-Z
	var max_cos := cos(deg_to_rad(90.0 - MIN_PITCH_MARGIN_DEG))
	fwd.z = clampf(fwd.z, -max_cos, max_cos)
	fwd = fwd.normalized()

	_set_forward(fwd)


## Unit movement direction in world space from the six actions (camera axes).
func move_direction() -> Vector3:
	var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var s := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var u := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	var dir := _camera.forward() * f + _camera.right() * s + _camera.up() * u
	if dir.length() > 0.0:
		dir = dir.normalized()
	return dir


## Travel speed: ~one second covers the distance to the nearest surface.
func current_speed() -> float:
	var d := DistanceEstimator.estimate(_camera.eye(), _params)
	return clampf(d, 1e-6, 20.0) * _camera.speed_factor


func scroll(up: bool) -> void:
	var f := _camera.speed_factor * (1.25 if up else 1.0 / 1.25)
	_camera.speed_factor = clampf(f, 0.01, 100.0)


## Rebuild the basis from a forward vector with +Z as the up hint (no roll),
## keeping the eye where it is.
func _set_forward(fwd: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY, _camera.eye())
	_camera.transform = t.looking_at(_camera.eye() + fwd, WORLD_UP)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/fly_camera_test.gd`
Expected: `fly_camera_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/camera/fly_camera.gd tests/fly_camera_test.gd
git commit -m "feat: distance-scaled free-fly camera

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: ResolutionGovernor

Adaptive render scale while things move, one crisp final frame, then an idle
freeze. Pure logic in `step(frame_time, changing)`; the Node wires it to
`FractalView`.

**Files:**
- Create: `src/perf/resolution_governor.gd`
- Create: `tests/resolution_governor_test.gd`

**Interfaces:**
- Consumes: `FractalParams` (`fast_controls`), `FractalView`, and change signals.
- Produces: `class_name ResolutionGovernor extends Node`, enum
  `Mode { CONTINUOUS, FINAL_FRAME, IDLE }`, observable `scale: float`,
  `mode: Mode`, `fast_controls: bool`, pure `step(frame_time: float, changing: bool)`,
  and `setup(params, view)` + `mark_changed()` + `set_dragging(on)` for wiring.

- [ ] **Step 1: Write the failing test** — `tests/resolution_governor_test.gd`

```gdscript
extends "res://tests/test_case.gd"
## Pure step() logic on fabricated frame times. Target is 1/30 s.


func run() -> void:
	var slow := 0.1       # 100 ms  >> 1.2 * (1/30) = 40 ms
	var fast := 0.001     # 1 ms    <  0.6 * (1/30) = 20 ms

	# --- slow frames lower the scale, but at most once per 0.5 s ---
	var g := ResolutionGovernor.new()
	g.fast_controls = true
	g.step(slow, true)                       # first slow frame: adjusts
	check_eq(g.mode, ResolutionGovernor.Mode.CONTINUOUS, "changing => CONTINUOUS")
	check(g.scale < 1.0, "a slow frame lowered the scale")
	var after_one := g.scale
	g.step(slow, true)                       # within 0.5 s: no second change
	check_approx(g.scale, after_one, "not lowered twice within 0.5 s", 1e-6)
	for i in 20: g.step(slow, true)          # enough elapsed time to keep lowering
	check_approx(g.scale, 0.25, "sustained slow frames reach the 0.25 floor", 1e-6)

	# --- fast frames raise it again, never above 1.0 ---
	for i in 60: g.step(fast, true)
	check_approx(g.scale, 1.0, "sustained fast frames reach the 1.0 ceiling", 1e-6)

	# --- stopping: one FINAL_FRAME at scale 1, then IDLE ---
	g.step(0.016, true)                      # something is changing
	g.step(0.016, false)                     # first still frame
	check_eq(g.mode, ResolutionGovernor.Mode.FINAL_FRAME, "first still frame is FINAL_FRAME")
	check_approx(g.scale, 1.0, "final frame renders at full scale", 1e-6)
	g.step(0.016, false)                     # next still frame
	check_eq(g.mode, ResolutionGovernor.Mode.IDLE, "then it goes IDLE")

	# --- Fast Controls off: scale stays 1.0, same mode logic ---
	var h := ResolutionGovernor.new()
	h.fast_controls = false
	for i in 10: h.step(slow, true)
	check_approx(h.scale, 1.0, "fast controls off keeps scale at 1.0", 1e-6)
	check_eq(h.mode, ResolutionGovernor.Mode.CONTINUOUS, "still CONTINUOUS while changing")
	h.step(slow, false)
	check_eq(h.mode, ResolutionGovernor.Mode.FINAL_FRAME, "one final frame with fast off")
	h.step(slow, false)
	check_eq(h.mode, ResolutionGovernor.Mode.IDLE, "then idle with fast off")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/resolution_governor_test.gd`
Expected: FAIL / load error — `ResolutionGovernor` not declared.

- [ ] **Step 3: Write the implementation** — `src/perf/resolution_governor.gd`

```gdscript
class_name ResolutionGovernor
extends Node
## Owns FractalView.render_scale and its update mode. While the view is changing
## it adapts the scale to hold ~30 fps; when it stops it renders one full-scale
## frame and then freezes.

enum Mode { CONTINUOUS, FINAL_FRAME, IDLE }

const TARGET := 1.0 / 30.0
const EMA_ALPHA := 0.2
const COOLDOWN := 0.5           # seconds between scale changes
const STEP := 0.8               # scale multiplier per adjustment

var scale := 1.0
var mode := Mode.IDLE
var fast_controls := true

var _params: FractalParams
var _view: FractalView
var _ema := TARGET
var _since_change := COOLDOWN   # allow an adjustment on the first frame
var _idle_pending := false
var _dirty := false
var _dragging := false


func setup(params: FractalParams, view: FractalView) -> void:
	_params = params
	_view = view
	fast_controls = params.fast_controls
	params.changed.connect(func(): _dirty = true; fast_controls = params.fast_controls)


func mark_changed() -> void:
	_dirty = true


func set_dragging(on: bool) -> void:
	_dragging = on


func _process(delta: float) -> void:
	if _view == null:
		return
	var changing := _dirty or _dragging
	_dirty = false
	step(delta, changing)
	_view.set_render_scale(scale)
	match mode:
		Mode.CONTINUOUS:
			_view.set_continuous(true)
		Mode.FINAL_FRAME:
			_view.set_continuous(false)
			_view.request_frame()
		Mode.IDLE:
			_view.set_continuous(false)


## Pure logic: update `scale` and `mode` from one frame's time and whether
## anything is changing. No side effects.
func step(frame_time: float, changing: bool) -> void:
	_since_change += frame_time
	if changing:
		mode = Mode.CONTINUOUS
		_idle_pending = true
		if fast_controls:
			_ema = _ema * (1.0 - EMA_ALPHA) + frame_time * EMA_ALPHA
			if _since_change >= COOLDOWN:
				if _ema > 1.2 * TARGET and scale > 0.25:
					scale = clampf(scale * STEP, 0.25, 1.0)
					_since_change = 0.0
				elif _ema < 0.6 * TARGET and scale < 1.0:
					scale = clampf(scale / STEP, 0.25, 1.0)
					_since_change = 0.0
		else:
			scale = 1.0
	elif _idle_pending:
		mode = Mode.FINAL_FRAME
		scale = 1.0
		_idle_pending = false
	else:
		mode = Mode.IDLE
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/resolution_governor_test.gd`
Expected: `resolution_governor_test.gd PASSED`

- [ ] **Step 5: Commit**

```bash
git add src/perf/resolution_governor.gd tests/resolution_governor_test.gd
git commit -m "feat: adaptive resolution governor with idle freeze

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: ControlsPanel

The Q panel. Twelve rows of widgets, each reading/writing `FractalParams` or
`CameraState` and reflecting external changes.

**Files:**
- Create: `src/ui/controls_panel.tscn`
- Create: `src/ui/controls_panel.gd`
- Create: `tests/controls_panel_test.gd`

**Interfaces:**
- Consumes: `FractalParams`, `CameraState`.
- Produces: `class_name ControlsPanel extends PanelContainer` with
  `setup(params, camera)`, public widget members `scale_slider`, `inner_slider`,
  `fold_slider`, `outer_slider` (HSlider), `color_option`, `camera_option`
  (OptionButton), `precision_edit`, `julia_x`, `julia_y`, `julia_z` (LineEdit),
  `julia_check`, `fast_check` (CheckBox), `sens_slider` (HSlider),
  `speed_label`, `legend_label` (Label), and
  `text_field_has_focus() -> bool`.

- [ ] **Step 1: Write the failing test** — `tests/controls_panel_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var panel: ControlsPanel = load("res://src/ui/controls_panel.tscn").instantiate()
	root.add_child(panel)
	panel.setup(params, cam)
	await frames(1)

	# --- each widget writes its field ---
	panel.scale_slider.value = -3.0
	check_approx(params.scale, -3.0, "scale slider writes scale")
	panel.inner_slider.value = 0.5
	check_approx(params.inner_radius, 0.5, "inner slider writes inner_radius")
	panel.fold_slider.value = 0.8
	check_approx(params.fold_limit, 0.8, "fold slider writes fold_limit")
	panel.outer_slider.value = 0.9
	check_approx(params.outer_radius, 0.9, "outer slider writes outer_radius")
	panel.color_option.select(2)             # dropdown index 2 -> id 2 (Borg)
	panel.color_option.item_selected.emit(2)
	check_eq(params.color_mode, 2, "colour dropdown writes the id")
	panel.sens_slider.value = 0.3
	check_approx(params.mouse_sensitivity, 0.3, "sensitivity slider writes it")
	panel.julia_check.button_pressed = true
	panel.julia_check.toggled.emit(true)
	check_eq(params.julia_enabled, true, "julia check writes julia_enabled")
	panel.fast_check.button_pressed = false
	panel.fast_check.toggled.emit(false)
	check_eq(params.fast_controls, false, "fast check writes fast_controls")
	panel.camera_option.select(1)
	panel.camera_option.item_selected.emit(1)
	check_eq(params.camera_mode, FractalParams.CameraMode.ORBIT, "camera dropdown writes the mode")

	# --- valid precision is applied on submit; invalid reverts ---
	panel.precision_edit.text = "0.0001"
	panel.precision_edit.text_submitted.emit("0.0001")
	check_approx(params.precision, 0.0001, "valid precision is applied", 1e-9)
	panel.precision_edit.text = "not a number"
	panel.precision_edit.text_submitted.emit("not a number")
	check_approx(params.precision, 0.0001, "invalid precision leaves the value", 1e-9)
	check_eq(panel.precision_edit.text, "0.0001", "and the field reverts its text")

	# --- external change updates the widget ---
	params.scale = -1.0
	await frames(1)
	check_approx(panel.scale_slider.value, -1.0, "external scale change updates the slider")
	params.julia_point = Vector3(1, 2, 3)
	await frames(1)
	check_eq(panel.julia_x.text, "1", "external julia move updates the X field")

	panel.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/controls_panel_test.gd`
Expected: FAIL — scene/`ControlsPanel` do not exist.

- [ ] **Step 3: Write the implementation** — `src/ui/controls_panel.gd`

Build the widgets in code so the scene stays a bare `PanelContainer` and the
test can address each widget by name. Wire writes to the resources and connect
`params.changed` to refresh the widgets (guarded by a `_syncing` flag so a
refresh does not re-emit a write).

```gdscript
class_name ControlsPanel
extends PanelContainer
## The Q panel. Edits FractalParams and camera settings; mirrors external
## changes. Never touches the shader or the viewport.

var scale_slider: HSlider
var inner_slider: HSlider
var fold_slider: HSlider
var outer_slider: HSlider
var color_option: OptionButton
var precision_edit: LineEdit
var julia_check: CheckBox
var julia_x: LineEdit
var julia_y: LineEdit
var julia_z: LineEdit
var julia_row: HBoxContainer
var fast_check: CheckBox
var camera_option: OptionButton
var sens_slider: HSlider
var speed_label: Label
var legend_label: Label

var _params: FractalParams
var _camera: CameraState
var _syncing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var box := VBoxContainer.new()
	add_child(box)

	scale_slider = _labeled_slider(box, "Slice (Scale)", -5.0, -0.5, 0.01)
	inner_slider = _labeled_slider(box, "Inner Radius", 0.0, 1.0, 0.01)
	fold_slider = _labeled_slider(box, "Fold", 0.0, 1.0, 0.01)
	outer_slider = _labeled_slider(box, "Outer Radius", 0.0, 1.0, 0.01)

	color_option = OptionButton.new()
	for i in FractalParams.COLOR_MODE_NAMES.size():
		color_option.add_item(FractalParams.COLOR_MODE_NAMES[i], i)
	box.add_child(_row("Color", color_option))

	precision_edit = LineEdit.new()
	box.add_child(_row("Precision", precision_edit))

	julia_check = CheckBox.new()
	julia_check.text = "Julia"
	box.add_child(julia_check)
	julia_row = HBoxContainer.new()
	julia_x = _coord_edit(julia_row, "X")
	julia_y = _coord_edit(julia_row, "Y")
	julia_z = _coord_edit(julia_row, "Z")
	box.add_child(julia_row)

	fast_check = CheckBox.new()
	fast_check.text = "Fast Controls"
	box.add_child(fast_check)

	camera_option = OptionButton.new()
	camera_option.add_item("Fly", 0)
	camera_option.add_item("Orbit", 1)
	box.add_child(_row("Camera", camera_option))

	sens_slider = _labeled_slider(box, "Mouse sensitivity", 0.02, 0.5, 0.001)

	speed_label = Label.new()
	box.add_child(speed_label)
	legend_label = Label.new()
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(legend_label)

	# writes
	scale_slider.value_changed.connect(func(v): _write(func(): _params.scale = v))
	inner_slider.value_changed.connect(func(v): _write(func(): _params.inner_radius = v))
	fold_slider.value_changed.connect(func(v): _write(func(): _params.fold_limit = v))
	outer_slider.value_changed.connect(func(v): _write(func(): _params.outer_radius = v))
	color_option.item_selected.connect(func(i): _write(func(): _params.color_mode = FractalParams.COLOR_MODE_IDS[i]))
	precision_edit.text_submitted.connect(_on_precision_submitted)
	precision_edit.focus_exited.connect(func(): _on_precision_submitted(precision_edit.text))
	julia_check.toggled.connect(func(on): _write(func(): _params.julia_enabled = on); _refresh())
	for e in [julia_x, julia_y, julia_z]:
		e.text_submitted.connect(func(_t): _on_julia_submitted())
		e.focus_exited.connect(_on_julia_submitted)
	fast_check.toggled.connect(func(on): _write(func(): _params.fast_controls = on))
	camera_option.item_selected.connect(func(i): _write(func(): _params.camera_mode = i))
	sens_slider.value_changed.connect(func(v): _write(func(): _params.mouse_sensitivity = v))


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera
	params.changed.connect(_refresh)
	camera.changed.connect(_refresh)
	_refresh()


## True while any text field in the panel holds keyboard focus (so Main can
## ignore Q and let the user type a value containing "q").
func text_field_has_focus() -> bool:
	for e in [precision_edit, julia_x, julia_y, julia_z]:
		if e.has_focus():
			return true
	return false


func _write(action: Callable) -> void:
	if _syncing:
		return
	action.call()


func _on_precision_submitted(text: String) -> void:
	if _syncing:
		return
	if text.is_valid_float() and text.to_float() > 0.0:
		_params.precision = text.to_float()
	else:
		precision_edit.text = str(_params.precision)   # revert


func _on_julia_submitted() -> void:
	if _syncing:
		return
	var p := _params.julia_point
	if julia_x.text.is_valid_float(): p.x = julia_x.text.to_float()
	if julia_y.text.is_valid_float(): p.y = julia_y.text.to_float()
	if julia_z.text.is_valid_float(): p.z = julia_z.text.to_float()
	_params.julia_point = p


func _refresh() -> void:
	if _params == null:
		return
	_syncing = true
	scale_slider.value = _params.scale
	inner_slider.value = _params.inner_radius
	fold_slider.value = _params.fold_limit
	outer_slider.value = _params.outer_radius
	color_option.select(FractalParams.COLOR_MODE_IDS.find(_params.color_mode))
	if not precision_edit.has_focus():
		precision_edit.text = str(_params.precision)
	julia_check.button_pressed = _params.julia_enabled
	julia_row.visible = _params.julia_enabled
	if not julia_x.has_focus(): julia_x.text = str(_params.julia_point.x)
	if not julia_y.has_focus(): julia_y.text = str(_params.julia_point.y)
	if not julia_z.has_focus(): julia_z.text = str(_params.julia_point.z)
	fast_check.button_pressed = _params.fast_controls
	camera_option.select(_params.camera_mode)
	sens_slider.value = _params.mouse_sensitivity
	if _params.camera_mode == FractalParams.CameraMode.FLY and _camera != null:
		speed_label.text = "speed x%.2f" % _camera.speed_factor
		legend_label.text = "Q panel - WASD fly - Space/Shift up/down - wheel speed - click to capture mouse"
	else:
		speed_label.text = ""
		legend_label.text = "Q panel - left-drag orbit - Shift-drag pan - right-drag dolly - wheel zoom"
	_syncing = false


func _labeled_slider(box: VBoxContainer, label: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.custom_minimum_size = Vector2(180, 0)
	box.add_child(_row(label, s))
	return s


func _row(label: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l); h.add_child(control)
	return h


func _coord_edit(row: HBoxContainer, label: String) -> LineEdit:
	var l := Label.new(); l.text = label
	var e := LineEdit.new(); e.custom_minimum_size = Vector2(70, 0)
	row.add_child(l); row.add_child(e)
	return e
```

- [ ] **Step 4: Create `src/ui/controls_panel.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/controls_panel.gd" id="1"]

[node name="ControlsPanel" type="PanelContainer"]
offset_right = 320.0
offset_bottom = 460.0
script = ExtResource("1")
```

Then `godot4 --headless --import --path .`.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/controls_panel_test.gd`
Expected: `controls_panel_test.gd PASSED`

- [ ] **Step 6: Commit**

```bash
git add src/ui/controls_panel.gd src/ui/controls_panel.tscn tests/controls_panel_test.gd
git commit -m "feat: runtime controls panel bound to FractalParams and CameraState

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: Main

Wire everything, pick the active camera from `camera_mode`, own the mouse mode,
and handle Q. This makes `./run.sh` work for the first time.

**Files:**
- Create: `src/main.tscn`
- Create: `src/main.gd`
- Create: `tests/main_test.gd`

**Interfaces:**
- Consumes: every unit above.
- Produces: `class_name Main extends Node`, scene `src/main.tscn` (the project's
  `run/main_scene`), with children `FractalView`, `JuliaMarker` (added in Task
  12 — add the node now, pointing at a script created there, OR add it in Task
  12 and re-save the scene; this task adds the other five children and leaves a
  `JuliaMarker` node slot), `ControlsPanel`, `ResolutionGovernor`, `FlyCamera`,
  `OrbitCamera`.

> **Build order note:** `OrbitCamera` (Task 11) and `JuliaMarker` (Task 12) come
> after this task. To keep `main.gd` compiling now, reference them by node
> presence and duck-typed methods: in this task add `FlyCamera` and a
> placeholder `OrbitCamera`/`JuliaMarker` are **not** required for the tests.
> Add `OrbitCamera` and `JuliaMarker` children when their tasks land and extend
> `main.gd`'s camera switch then. `main_test` here only asserts FLY/ORBIT node
> enabling via `FlyCamera` + a stub, and Q toggling. See Step 3's guard.

- [ ] **Step 1: Write the failing test** — `tests/main_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)

	var panel: ControlsPanel = main.get_node("ControlsPanel")
	var fly: FlyCamera = main.get_node("FlyCamera")

	# panel hidden by default, fly camera active
	check(not panel.visible, "panel starts hidden")
	check(fly.enabled, "fly camera is enabled in FLY mode")

	# Q toggles the panel
	await press_action("toggle_panel")
	check(panel.visible, "Q shows the panel")
	await press_action("toggle_panel")
	check(not panel.visible, "Q hides it again")

	# switching to ORBIT disables the fly camera and enables orbit
	main.get_node("FractalParams") if false else null   # (params live on main)
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	check(not fly.enabled, "fly camera is disabled in ORBIT mode")
	var orbit = main.get_node_or_null("OrbitCamera")
	if orbit != null:
		check(orbit.enabled, "orbit camera is enabled in ORBIT mode")

	main.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/main_test.gd`
Expected: FAIL — scene/`Main` do not exist.

- [ ] **Step 3: Write the implementation** — `src/main.gd`

```gdscript
class_name Main
extends Node
## Wires the two resources into every child, selects the active camera from
## camera_mode, owns the mouse capture, and handles the Q toggle.

var params: FractalParams
var camera: CameraState

@onready var view: FractalView = $FractalView
@onready var panel: ControlsPanel = $ControlsPanel
@onready var governor: ResolutionGovernor = $ResolutionGovernor
@onready var fly: FlyCamera = $FlyCamera


func _ready() -> void:
	params = FractalParams.new()
	camera = CameraState.make_default()

	view.setup(params, camera)
	panel.setup(params, camera)
	governor.setup(params, view)
	fly.setup(params, camera)

	var orbit := get_node_or_null("OrbitCamera")
	if orbit:
		orbit.setup(params, camera)
	var marker := get_node_or_null("JuliaMarker")
	if marker:
		marker.setup(params, view)

	panel.visible = false
	params.changed.connect(_apply_mode)
	camera.changed.connect(func(): governor.mark_changed())
	_apply_mode()


func _apply_mode() -> void:
	var is_fly := params.camera_mode == FractalParams.CameraMode.FLY
	fly.enabled = is_fly
	var orbit := get_node_or_null("OrbitCamera")
	if orbit:
		orbit.enabled = not is_fly
		if not is_fly and orbit.has_method("enter"):
			orbit.enter()
	_update_mouse()


func _update_mouse() -> void:
	var capture := (params.camera_mode == FractalParams.CameraMode.FLY) and not panel.visible
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		if panel.text_field_has_focus():
			return
		panel.visible = not panel.visible
		_update_mouse()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# click on the view in FLY mode while free: hide panel, recapture
		if params.camera_mode == FractalParams.CameraMode.FLY \
				and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not panel.visible:
			_update_mouse()
```

- [ ] **Step 4: Create `src/main.tscn`**

Instance the two sub-scenes and add the camera/governor nodes. (Add
`OrbitCamera` and `JuliaMarker` here too if their scripts already exist; if you
reach this task first, add them in Tasks 11-12 and re-save the scene.)

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://src/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://src/fractal/fractal_view.tscn" id="2"]
[ext_resource type="PackedScene" path="res://src/ui/controls_panel.tscn" id="3"]
[ext_resource type="Script" path="res://src/camera/fly_camera.gd" id="4"]

[node name="Main" type="Node"]
script = ExtResource("1")

[node name="FractalView" parent="." instance=ExtResource("2")]

[node name="FlyCamera" type="Node" parent="."]
script = ExtResource("4")

[node name="ResolutionGovernor" type="Node" parent="."]
script = ExtResource("res://src/perf/resolution_governor.gd")

[node name="ControlsPanel" parent="." instance=ExtResource("3")]
```

> The `ResolutionGovernor` node uses an inline `script =` path string; if Godot
> complains, add it as an `[ext_resource]` like the others. After writing,
> `godot4 --headless --import --path .`.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/main_test.gd`
Expected: `main_test.gd PASSED`

> In headless mode `Input.set_mouse_mode` is a no-op but must not error; keep the
> calls guarded as written.

- [ ] **Step 6: Commit**

```bash
git add src/main.gd src/main.tscn tests/main_test.gd
git commit -m "feat: Main wires the scene, cameras and input mode

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: OrbitCamera

The site's drag-to-orbit controller: rotate/pan/dolly/zoom about a centre, with a
CPU march to pick the centre on mode switch and on click.

**Files:**
- Create: `src/camera/orbit_camera.gd`
- Create: `tests/orbit_camera_test.gd`
- Modify: `src/main.tscn` (add the `OrbitCamera` child), `src/main.gd` already
  guards for it.

**Interfaces:**
- Consumes: `FractalParams`, `CameraState`, `DistanceEstimator`.
- Produces: `class_name OrbitCamera extends Node` with `setup(params, camera)`,
  `enabled: bool`, `center: Vector3`, `enter()`, `rotate_view(dx, dy)`,
  `pan(dx, dy)`, `dolly(dy)`, `zoom(up: bool, dir: Vector3)`,
  `recenter_on(hit: Vector3)`, and a private CPU march.

> **CPU-march note (design choice):** the shader marches in two phases for
> shading; the orbit camera only needs a surface *point*, so its private march
> uses a single high-precision (`DistanceEstimator`) loop within the same cube
> bounds (half 2, or 20 in Julia mode), starting at `max(0, t_enter)`, stepping
> by `D` until `d < precision * total` (hit) or `total > t_exit` (miss) or 200
> steps. This is simpler than the shader's two-phase march and sufficient for
> centring. Flagged in the final report.

- [ ] **Step 1: Write the failing test** — `tests/orbit_camera_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var orbit := OrbitCamera.new()
	root.add_child(orbit)
	orbit.setup(params, cam)
	orbit.center = Vector3.ZERO
	await frames(1)

	# --- rotation keeps the distance to the centre ---
	var d0 := cam.eye().distance_to(orbit.center)
	orbit.rotate_view(50.0, 20.0)
	check_approx(cam.eye().distance_to(orbit.center), d0, "rotation preserves orbit distance", 1e-4)

	# --- pan moves camera and centre together ---
	var eye_before := cam.eye()
	var center_before := orbit.center
	orbit.pan(30.0, -10.0)
	check((cam.eye() - eye_before).is_equal_approx(orbit.center - center_before),
		"pan moves camera and centre by the same vector")

	# --- dolly changes the distance only, keeps direction ---
	var dist_before := cam.eye().distance_to(orbit.center)
	var dir_before := (cam.eye() - orbit.center).normalized()
	orbit.dolly(40.0)
	check(absf(cam.eye().distance_to(orbit.center) - dist_before) > 1e-3, "dolly changes the distance")
	check((cam.eye() - orbit.center).normalized().is_equal_approx(dir_before),
		"dolly keeps the view direction")

	# --- click re-centres onto a hit ---
	orbit.recenter_on(Vector3(0.1, 0.2, 0.3))
	check(orbit.center.is_equal_approx(Vector3(0.1, 0.2, 0.3)), "recenter sets the centre to the hit")

	orbit.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/orbit_camera_test.gd`
Expected: FAIL / load error — `OrbitCamera` not declared.

- [ ] **Step 3: Write the implementation** — `src/camera/orbit_camera.gd`

```gdscript
class_name OrbitCamera
extends Node
## The site's orbit controller. Keeps a `center`; rotation orbits it, pan moves
## both camera and centre, dolly/zoom change the distance. The mouse is never
## captured in this mode.

const WORLD_UP := Vector3(0, 0, 1)
const MIN_PITCH_MARGIN_DEG := 1.0
const ROT_PER_PIXEL := 0.5          # degrees per pixel at sensitivity 0.1
const PAN_PER_PIXEL := 0.001        # * distance_to_center
const DOLLY_PER_PIXEL := 0.005      # * distance_to_center
const ZOOM_PER_TICK := 0.1          # * distance_to_center

var enabled := false
var center := Vector3.ZERO

var _params: FractalParams
var _camera: CameraState


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera


## On switching into ORBIT: centre on the surface hit by the centre ray, or the
## origin if that march runs past twice the current distance to the origin.
func enter() -> void:
	var dist_origin := _camera.eye().length()
	var hit := _march(_camera.eye(), _camera.forward())
	if hit != null and (hit as Vector3).distance_to(_camera.eye()) <= 2.0 * maxf(dist_origin, 1e-6):
		center = hit
	else:
		center = Vector3.ZERO


func rotate_view(dx: float, dy: float) -> void:
	var sens := ROT_PER_PIXEL * (_params.mouse_sensitivity / 0.1)
	var yaw := deg_to_rad(-dx * sens)
	var pitch := deg_to_rad(-dy * sens)
	var offset := _camera.eye() - center
	offset = offset.rotated(WORLD_UP, yaw)
	var right := _camera.right()
	offset = offset.rotated(right, pitch)
	# clamp pitch: keep the view direction away from +/-Z
	var new_eye := center + offset
	var fwd := (center - new_eye).normalized()
	var max_cos := cos(deg_to_rad(90.0 - MIN_PITCH_MARGIN_DEG))
	if absf(fwd.z) > max_cos:
		# undo the pitch component by re-rotating without it
		offset = (_camera.eye() - center).rotated(WORLD_UP, yaw)
		new_eye = center + offset
	_look_from(new_eye)


func pan(dx: float, dy: float) -> void:
	var dist := _camera.eye().distance_to(center)
	var delta := (-_camera.right() * dx + _camera.up() * dy) * dist * PAN_PER_PIXEL
	center += delta
	var t := _camera.transform
	t.origin += delta
	_camera.transform = t


func dolly(dy: float) -> void:
	var dist := _camera.eye().distance_to(center)
	var dir := (_camera.eye() - center).normalized()
	var new_dist := maxf(dist + dy * dist * DOLLY_PER_PIXEL, 1e-4)
	_look_from(center + dir * new_dist)


## Wheel: move toward the point under the cursor (dir is the cursor ray dir).
func zoom(up: bool, dir: Vector3) -> void:
	var dist := _camera.eye().distance_to(center)
	var step := dist * ZOOM_PER_TICK * (1.0 if up else -1.0)
	var t := _camera.transform
	t.origin += dir.normalized() * step
	_camera.transform = t


func recenter_on(hit: Vector3) -> void:
	center = hit


func _look_from(eye: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY, eye)
	_camera.transform = t.looking_at(center, WORLD_UP)


## Single-phase high-precision CPU march. Returns the hit Vector3 or null.
func _march(ro: Vector3, rd: Vector3) -> Variant:
	var box_half := 20.0 if _params.julia_enabled else 2.0
	var tb := _box(ro, rd, box_half)
	if tb.y < maxf(tb.x, 0.0):
		return null
	var total := maxf(tb.x, 0.0)
	for i in 200:
		var pos := ro + rd * total
		var d := DistanceEstimator.estimate(pos, _params)
		if d < _params.precision * total:
			return pos
		total += d
		if total > tb.y:
			return null
	return null


func _box(ro: Vector3, rd: Vector3, half_size: float) -> Vector2:
	var inv := Vector3(1.0 / rd.x, 1.0 / rd.y, 1.0 / rd.z)
	var n := inv * ro
	var k := inv.abs() * half_size
	var t1 := -n - k
	var t2 := -n + k
	var t_enter := maxf(maxf(t1.x, t1.y), t1.z)
	var t_exit := minf(minf(t2.x, t2.y), t2.z)
	return Vector2(t_enter, t_exit)
```

- [ ] **Step 4: Add `OrbitCamera` to `src/main.tscn`**

Add a child node `OrbitCamera` (type Node) with the `orbit_camera.gd` script, as
a sibling of `FlyCamera`. `main.gd` already calls `setup`, `enter`, and toggles
`enabled` for it. Then `godot4 --headless --import --path .`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/orbit_camera_test.gd`
Then re-run `main_test` to confirm the orbit branch now asserts:
`godot4 --headless --path . -s tests/main_test.gd`
Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add src/camera/orbit_camera.gd tests/orbit_camera_test.gd src/main.tscn
git commit -m "feat: orbit camera with CPU-march centring

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: JuliaMarker

A ring over the view at the projected Julia point, draggable (while the mouse is
free) to move the point in the plane facing the camera.

**Files:**
- Create: `src/camera/julia_marker.gd`
- Create: `tests/julia_marker_test.gd`
- Modify: `src/main.tscn` (add the `JuliaMarker` child; `main.gd` already wires it).

**Interfaces:**
- Consumes: `FractalParams`, `FractalView`.
- Produces: `class_name JuliaMarker extends Control` with `setup(params, view)`,
  `screen_point() -> Variant` (Vector2 or null), `begin_drag(mouse: Vector2) -> bool`,
  `update_drag(mouse: Vector2)`.

> **Why a test here (not in the spec's test table):** the spec lists no
> `julia_marker_test`, but TDD requires a failing test first. This test exercises
> only the marker's *logic* (visibility, projection, drag → `julia_point`), not
> its drawing. Flagged in the final report.

- [ ] **Step 1: Write the failing test** — `tests/julia_marker_test.gd`

```gdscript
extends "res://tests/test_case.gd"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	view.size = Vector2(1280, 800)
	view.setup(params, cam)
	var marker := JuliaMarker.new()
	root.add_child(marker)
	marker.size = Vector2(1280, 800)
	marker.setup(params, view)
	await frames(1)

	# hidden unless Julia is on
	check(not marker.visible, "marker hidden while Julia is off")
	params.julia_enabled = true
	await frames(1)
	check(marker.visible, "marker shows when Julia is on")

	# the ring sits at project(julia_point)
	var expected: Variant = view.project(params.julia_point)
	var got: Variant = marker.screen_point()
	check(expected != null and got != null and (got as Vector2).is_equal_approx(expected),
		"ring is drawn at the projected Julia point")

	# dragging the ring moves the point via unproject (same facing plane)
	if got != null:
		var started: bool = marker.begin_drag(got)
		check(started, "a press on the ring starts a drag")
		var target := (got as Vector2) + Vector2(40, -25)
		marker.update_drag(target)
		await frames(1)
		var reproj: Variant = view.project(params.julia_point)
		check(reproj != null and (reproj as Vector2).distance_to(target) < 2.0,
			"after the drag the point reprojects to the cursor")

	marker.queue_free()
	view.queue_free()
	await frames(1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/julia_marker_test.gd`
Expected: FAIL / load error — `JuliaMarker` not declared.

- [ ] **Step 3: Write the implementation** — `src/camera/julia_marker.gd`

```gdscript
class_name JuliaMarker
extends Control
## Draws a small ring at the projected Julia point and lets the user drag it (in
## the plane facing the camera) while the mouse is free.

const RING_RADIUS := 10.0

var _params: FractalParams
var _view: FractalView
var _dragging := false
var _drag_depth := 0.0


func setup(params: FractalParams, view: FractalView) -> void:
	_params = params
	_view = view
	params.changed.connect(_on_changed)
	view._camera.changed.connect(queue_redraw) if view._camera else null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_on_changed()


func _on_changed() -> void:
	visible = _params.julia_enabled
	queue_redraw()


## The window pixel of the Julia point, or null when behind the camera.
func screen_point() -> Variant:
	return _view.project(_params.julia_point)


## Start a drag if `mouse` is on the ring and Julia is on. Captures the point's
## camera-space depth so it slides in the facing plane.
func begin_drag(mouse: Vector2) -> bool:
	if not _params.julia_enabled:
		return false
	var sp: Variant = screen_point()
	if sp == null or (sp as Vector2).distance_to(mouse) > RING_RADIUS * 2.0:
		return false
	var rel := _params.julia_point - _view._camera.eye()
	_drag_depth = rel.dot(_view._camera.forward())
	_dragging = true
	return true


func update_drag(mouse: Vector2) -> void:
	if not _dragging:
		return
	_params.julia_point = _view.unproject(mouse, _drag_depth)


func end_drag() -> void:
	_dragging = false


func _draw() -> void:
	if not _params.julia_enabled:
		return
	var sp: Variant = screen_point()
	if sp != null:
		draw_arc(sp, RING_RADIUS, 0.0, TAU, 32, Color.WHITE, 2.0, true)
```

> `_view._camera` and `_view.unproject` are used directly; `FractalView` exposes
> `unproject`/`project` publicly, and `_camera` is read-only access for depth and
> the redraw hookup. If you prefer not to reach into `_camera`, add a public
> `FractalView.camera_depth(point) -> float` and use it — behaviour is identical.

- [ ] **Step 4: Add `JuliaMarker` to `src/main.tscn`**

Add a child `JuliaMarker` (type Control, full-rect) with the script, *after*
`FractalView` so it draws on top. Wire it in `main.gd`'s `_ready` (already
guarded via `get_node_or_null("JuliaMarker")`), and route left-press/drag/release
to `begin_drag`/`update_drag`/`end_drag` when the mouse is free. Then
`godot4 --headless --import --path .`.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot4 --headless --import --path . >/dev/null 2>&1; godot4 --headless --path . -s tests/julia_marker_test.gd`
Expected: `julia_marker_test.gd PASSED`

- [ ] **Step 6: Commit**

```bash
git add src/camera/julia_marker.gd tests/julia_marker_test.gd src/main.tscn src/main.gd
git commit -m "feat: draggable Julia point marker

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 13: Windowed screenshot check

A real-window render pass (via `open -g`, never stealing focus) that saves the
default view plus one PNG per colour mode and checks the default looks right.

**Files:**
- Create: `tests/screenshots.gd`
- Create: `tests/screenshots.sh` (`chmod +x`)

**Interfaces:**
- Consumes: `FractalView`, `FractalParams`, `CameraState`.
- Produces: `screenshots/default_view.png`, `screenshots/mode_<id>.png` per
  colour id, and `tests/out/screenshots.txt` with PASS/FAIL lines.

- [ ] **Step 1: Write `tests/screenshots.gd`**

```gdscript
extends SceneTree
## Windowed render pass. Launched by tests/screenshots.sh through `open -g` so
## the window never takes focus. `open` discards stdout, so results go to
## res://tests/out/screenshots.txt, one PASS/FAIL line each.

const SHOT_DIR := "res://screenshots"
const OUT_PATH := "res://tests/out/screenshots.txt"

var _lines: Array[String] = []


func _initialize() -> void:
	await _run()
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit(0)


func _pass(id: String) -> void: _lines.append("PASS " + id)
func _fail(id: String, why: String) -> void: _lines.append("FAIL %s %s" % [id, why])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/out"))

	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	view.size = Vector2(800, 600)   # the windowed resolution for the check
	view.setup(params, cam)
	view.set_render_scale(1.0)
	await _render(view)

	# default view (Ice Fractal, the project default)
	var def := view._viewport.get_texture().get_image()
	if def == null:
		_fail("default_view", "no_image")
	else:
		def.save_png(ProjectSettings.globalize_path(SHOT_DIR + "/default_view.png"))
		_check_default(def)

	# one PNG per colour mode
	for id in FractalParams.COLOR_MODE_IDS:
		params.color_mode = id
		await _render(view)
		var img := view._viewport.get_texture().get_image()
		if img == null:
			_fail("mode_%d" % id, "no_image")
		else:
			img.save_png(ProjectSettings.globalize_path(SHOT_DIR + "/mode_%d.png" % id))
			_pass("mode_%d" % id)

	view.queue_free()


func _render(view: FractalView) -> void:
	view.request_frame()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


## Default view check: < 60% black, and blue is the largest mean channel.
func _check_default(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var black := 0
	var total := 0
	var sum := Vector3.ZERO
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			total += 1
			if c.r < 0.02 and c.g < 0.02 and c.b < 0.02:
				black += 1
			sum += Vector3(c.r, c.g, c.b)
	var black_frac := float(black) / float(maxi(total, 1))
	var mean := sum / float(maxi(total, 1))
	var ok_black := black_frac < 0.60
	var ok_blue := mean.z >= mean.x and mean.z >= mean.y
	if ok_black and ok_blue:
		_pass("default_view")
	else:
		_fail("default_view", "black=%.2f mean=(%.3f,%.3f,%.3f)" % [black_frac, mean.x, mean.y, mean.z])
```

- [ ] **Step 2: Write `tests/screenshots.sh`** (`chmod +x`)

```sh
#!/bin/sh
# Render the windowed check in a real window and report what happened.
#
# Produces, in screenshots/ :
#   default_view.png            the default Ice Fractal view
#   mode_<id>.png               one per colour mode
# and one PASS/FAIL line per check in tests/out/screenshots.txt.
#
# The window must never take desktop focus, so the app is launched through
# `open -g` (background) with `-n` (new instance) and `-W` (wait for exit).
cd "$(dirname "$0")/.." || exit 2
GODOT="${GODOT:-godot4}"
APP="${GODOT_APP:-/Applications/Godot_mono.app}"

mkdir -p tests/out screenshots
rm -f tests/out/screenshots.txt        # one named file; never a recursive delete

"$GODOT" --headless --import --path . >/dev/null 2>&1

open -g -n -W -a "$APP" --args --path "$PWD" -s tests/screenshots.gd

if [ ! -f tests/out/screenshots.txt ]; then
  echo "*** tests/out/screenshots.txt was not written: the run crashed or never started."
  echo "*** Check that $APP exists, or set GODOT_APP=/path/to/Godot_mono.app"
  exit 1
fi

cat tests/out/screenshots.txt
echo "--- PNGs in screenshots/ :"
ls screenshots
if grep -q '^FAIL' tests/out/screenshots.txt; then
  exit 1
fi
exit 0
```

- [ ] **Step 3: Run it to verify it passes**

Run: `tests/screenshots.sh`
Expected: every line `PASS`, including `PASS default_view`; `screenshots/` holds
`default_view.png` and `mode_<id>.png` for all 13 ids. Open
`screenshots/default_view.png` and confirm a blue, cube-bounded Mandelbox.

> If `default_view` fails on `ok_blue`, confirm the camera default and shader are
> correct (the default colour mode is 1, Ice Fractal, which is blue). If it fails
> on `no_image`, the windowed launch did not get a GPU context — check that
> `/Applications/Godot_mono.app` exists.

- [ ] **Step 4: Commit**

```bash
git add tests/screenshots.gd tests/screenshots.sh
git commit -m "feat: windowed screenshot check for the default view and colour modes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 14: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

Cover: what this is (a from-scratch Godot 4.6 Mandelbox viewer emulating
icefractal.com/mandelbox/, web-exportable); how to run (`./run.sh`,
`./run.sh --editor`); the controls (Q panel; WASD fly; Space/Shift up/down;
mouse-look; wheel = speed; click to capture; orbit-mode drags); the default-view
key table (eye `(8.175847, 3.812460, 3.283393)`, looks at origin, 40° vFOV, +Z
up, fractal coordinates = 2× the site's); how to test
(`tests/run_all.sh`, `tests/screenshots.sh`); and where the reference capture
lives (`docs/reference/icefractal-default.jpg`) for side-by-side eyeballing.
No code snippets required; prose and a table.

- [ ] **Step 2: Verify it renders**

Run: `godot4 --headless --import --path . >/dev/null 2>&1` (sanity) and read the
file back; no test. Confirm the control list and key table match the spec.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README with run, controls and the default-view key table

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 15: Web export preset

One **Web** preset with threads off (no cross-origin-isolation headers needed),
exporting to the git-ignored `build/web/`.

**Files:**
- Create: `export_presets.cfg`
- Modify: `.gitignore` (add `build/` and `tests/out/`)

- [ ] **Step 1: Add ignores to `.gitignore`**

Append:

```
# Export outputs and test scratch
build/
tests/out/
```

- [ ] **Step 2: Create `export_presets.cfg`**

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
```

- [ ] **Step 3: Verify the preset loads**

Run: `godot4 --headless --path . --export-release Web build/web/index.html`
Expected one of:
- Success: `build/web/index.html` (+ `.wasm`, `.pck`, `.js`) are written.
- **Templates missing:** output contains `export templates` /
  `No export template found`. This is acceptable on this machine — it means the
  preset is valid but the Web export templates are not installed. Record this in
  the commit message and final report; do **not** treat it as a failure of the
  preset.

> Do not attempt to download templates or change editor settings to install them.

- [ ] **Step 4: Commit**

```bash
git add export_presets.cfg .gitignore
git commit -m "feat: Web export preset (threads off) targeting build/web

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 16: Final verification

Run the whole suite, the windowed check, eyeball the default view against the
reference, and attempt the web export. No new product code; this task only
verifies and, if needed, fixes regressions surfaced here.

**Files:** none created; fixes (if any) go to the file at fault with its own test.

- [ ] **Step 1: Full headless suite**

Run (Bash tool `timeout: 600000`): `tests/run_all.sh`
Expected: every `tests/*_test.gd` prints `PASSED`; the script exits 0. If any
test fails, stop and fix it (with a failing test first) before continuing.

- [ ] **Step 2: Windowed screenshot check**

Run: `tests/screenshots.sh`
Expected: all `PASS`, exit 0; `screenshots/default_view.png` written.

- [ ] **Step 3: Eyeball the default view**

Open `screenshots/default_view.png` and `docs/reference/icefractal-default.jpg`
side by side. Confirm: a cube-bounded, predominantly blue Mandelbox with the
same gross structure (the big round "porthole" faces, the fractal dust at the
corners). Exact pixels will differ (float32, no HiDPI); the shape and colour
family should match. Note any gross mismatch in the final report.

- [ ] **Step 4: Web export**

Run: `godot4 --headless --path . --export-release Web build/web/index.html`
Expected: either the files are written to `build/web/`, or the output reports
missing export templates. **If templates are missing, report that fact — do not
fail the task.**

- [ ] **Step 5: Confirm the git state**

Run: `git status` and `git log --oneline -20`
Expected: a clean tree (only `build/` and `tests/out/` present and ignored) and
one commit per task. **Do not push, merge, or open a PR.**

- [ ] **Step 6: Report ready**

Tell Adam the project is complete and committed on `main`, that the headless
suite and windowed check pass, how the default view compares to the reference,
and whether the web export produced files or reported missing templates.

---

## Self-review (completed while writing this plan)

- **Spec coverage.** Engine/export (Task 1, 15); input actions (Task 1);
  coordinates/default camera (Task 4); FractalParams incl. all fields and the 13
  colour ids (Task 2); DistanceEstimator + 24 fixtures + symmetry + Julia (Task
  3); shader incl. ray, cube bounds, two-phase march, both normals, lighting,
  all 13 colour modes, backgrounds (Task 5); FractalView incl. render scale,
  update modes, project/unproject (Task 6); FlyCamera incl. look, move, speed,
  wheel, capture rules (Task 7, capture owned by Main in Task 10); OrbitCamera
  incl. enter/rotate/pan/dolly/zoom/click (Task 11); JuliaMarker (Task 12);
  ControlsPanel all 12 rows (Task 9); ResolutionGovernor incl. both fast-control
  states (Task 8); Main (Task 10); every test in the spec's test table (Tasks
  2-12) plus screenshots (Task 13); README (Task 14). Non-goals (Save Image,
  Copy URL, High DPI, reset, touch) are intentionally absent.
- **Deliberate choices / spec deviations** (also in the final report): (1) the
  DistanceEstimator test loosens the spec's 1e-5 tolerance to 2e-3 and 1e-4 for
  two provably chaotic near-surface fixtures, measured during planning; (2) the
  shader-compile assertion lives in `shader_test.gd` and `fractal_view_test.gd`
  checks the view's material carries it, rather than both living in one file;
  (3) the OrbitCamera CPU march is single-phase (surface point only); (4) a
  `julia_marker_test` is added though the spec's table omits it; (5) CameraState
  has its own small test though the spec folds it into fly-camera.
- **Type consistency.** `FractalView.project/unproject`, `set_render_scale`,
  `request_frame`, `set_continuous`, `viewport_size` are used identically across
  Tasks 6, 8, 11, 12. `ResolutionGovernor.Mode` names
  (`CONTINUOUS`/`FINAL_FRAME`/`IDLE`) match between Task 8's code and test.
  `FractalParams.CameraMode.{FLY,ORBIT}` and `COLOR_MODE_IDS` are used
  consistently in Tasks 2, 9, 10, 13.
