# Debug console — design

A second, native OS window that is "Fractacular embedded": the Shape inspector
with Fractacular's binding rows, and a Movement pane of virtual axes driven by
key pairs. The shape it edits is always the 3D Mandelbox being flown through in
the main window. The Q panel goes away; what it held that is not a shape knob
moves to the pause menu and the settings menu.

Decisions below come from the brainstorm on 2026-10-07. The quick control
changes that preceded it (Shift sprints, Backspace descends, a Ctrl tap toggles
the panel, Q and E freed) are a separate branch, `quick-controls`, and this
design builds on them: the Ctrl tap now opens the console instead of the panel.

## Goals

- Every knob of Fractacular's Mandelbox technique on the 3D shape: Box
  (scale, fold limit, the two radii, fold order), per-component Julia with four
  constants, the six iteration-rotation angles, plus the fourth coordinate of
  the sample point. The same formula in the shader, in the Ice Fractal field
  and in the GDScript distance estimator.
- Fractacular's binding model on each knob: `value = default + gain ×
  waveform(source)`, where a source is the clock or a **virtual axis**.
- Virtual axes that key pairs push at a speed, unbounded, defined in a
  **keymap file** that game code can rewrite at runtime, since the bindings
  will change from level to level.
- A native second window (drag it to another monitor), toggled by a Ctrl tap,
  split Shape | Movement. The web export falls back to an embedded window.
- Saved views carry the knob defaults, the bindings and the axis values; old
  saves still load.
- Everything but pixels tested headlessly, in the style of `tests/`; the
  default picture unchanged, checked by the screenshot pass.

## Non-goals

Fractacular's 2D field panels, isolation panels and the isolation graph editor;
the fluid; the Colour (palette) window; the desktop canvas of floating windows;
Performance window. Clock controls (pause, reset, speed): Time is a source, the
clock just runs. Bindings on noise-node parameters (the noise editor keeps its
own `NoiseParamSpec`/`NoiseParamTable`/`NoiseParamRow`; unifying them with the
ports below is a follow-up). Per-level loading: only the API a level will call.
Fractacular's `iterations`, `bailout` and `dimension` knobs: the march keeps its
fixed 16/32 iterations, and `dimension = 3D` is exactly `w = 0` here.

## Prerequisite

The renderer-options work in flight on `main` (level-of-detail knobs, max
steps, min render scale and Fast Controls on a Settings → Renderer tab; the
same keys in `Workspace`) lands first. This design leaves those fields on
`FractalParams` and in the settings menu; the console does not show them.

## The pieces

```
src/attributes/              <- ports of Fractacular's src/fields (no Category)
  attribute_spec.gd            one knob: id, type, range, log, wrap, bindable, tooltip, effects, group
  attribute_table.gd           specs + a default per knob + a Binding per bindable knob; changed(id)
  binding.gd                   source (StringName), gain, waveform, period
  binding_resolver.gd          (table, axis values, t) -> {id: value}, sanitized
src/axes/                    <- the movement layer (no drawing)
  axes.gd                      the virtual axes: id, label, speed, value (unbounded); changed
  keymap.gd                    axes <-> key pairs, the JSON file, InputMap actions; the rebind API
  axis_controller.gd           Node: reads the actions each frame, ignores keys while typing
  clock.gd                     t, seconds since the view opened
src/fractal/
  mandelbox_shape.gd           the catalogue: Fractacular's Mandelbox specs + Render group
  fractal_params.gd            the RESOLVED knob values + the renderer/preference fields
  mandelbox.gdshader           4D step: fold order, iteration rotation, per-component Julia
  distance_estimator.gd        the same step in 64-bit scalars
src/ui/console/
  console_window.gd            the native Window: HSplit of the two panes; Ctrl tap forwards
  attribute_row.gd             Fractacular's wide row: value widgets + source/gain/wave/period
  attribute_inspector.gd       the Shape pane: group headings + rows, live readouts
  movement_pane.gd             axes table, key capture, speed, clock readout, keymap Save/Load
  key_capture_button.gd        "press a key…" button that writes one physical key
src/ui/ctrl_tap.gd             the arm/disarm Ctrl-tap detector, shared by Main and the console
src/ui/text_focus.gd           TextFocus.any(viewports): is a LineEdit/TextEdit focused anywhere
```

### Attributes (ported)

`AttributeSpec`, `AttributeTable`, `Binding`, `BindingResolver` are ports of
Fractacular's with these changes:

- No `Category` (there is one table, the shape's). `AttributeSpec.make()`
  keeps the same keys; `sanitize()` is the same (wrap or clamp to the hard
  range, INT rounds, ENUM falls back to the default).
- `Binding.source` is a `StringName`, not an enum: `&""` is none, `&"time"`
  the clock, anything else an axis id. `to_dict()` stores it as a string.
- `BindingResolver.resolve(table, axis_values: Dictionary, t: float)`: for each
  spec, the default if the binding is inactive or the spec is not bindable;
  otherwise `raw` is `t` for `&"time"`, the axis's value for a known axis id,
  and 0 for an unknown one (so a view bound to an axis the keymap lacks shows
  its default, not garbage). `wave` is Linear, Sine or Triangle exactly as in
  Fractacular. No isoclinic, no movement scale.

### The shape catalogue

`MandelboxShape.specs() -> Array[AttributeSpec]`, in inspector order. Ranges
are Fractacular's widened where the site's slider went further; defaults are
the site's, so the opening view is the one we have.

| group | id | type | default | slider | notes |
|---|---|---|---|---|---|
| Box | `box_scale` | FLOAT | −2.09 | −5 … 3, hard ±6 | Fractacular's `box_scale`; was `scale` |
| Box | `fold_limit` | FLOAT | 1.0 | 0 … 3 | |
| Box | `min_radius` | FLOAT | 0.7 | 0 … 2 | was `inner_radius` |
| Box | `fixed_radius` | FLOAT | 1.0 | 0 … 4 | was `outer_radius` |
| Box | `fold_order` | ENUM | Box → Sphere | | not bindable |
| Box | `w` | FLOAT | 0.0 | −4 … 4 | the sample point's fourth coordinate; 0 is today's 3D box |
| Julia | `julia_all` | BOOL | false | | was `julia_enabled`; drives the on-screen marker |
| Julia | `julia_0..3` | BOOL | false | | per component x, y, z, w |
| Julia | `c_0..3` | FLOAT | −0.23, 1.512, 1.892, 0 | −4 … 4 | was `julia_point`; shown while its toggle or `julia_all` is on |
| Iteration rotation | `iter_rot_xy … zw` | FLOAT | 0 | ±180, wrap | six planes |
| Render | `color_mode` | ENUM | Ice Fractal | | the thirteen site modes, by site id; not bindable |
| Render | `precision` | FLOAT | 0.000025 | 1e-6 … 1e-3, log | |

Every spec carries Fractacular's `tooltip` and `effects` text (copied for the
Mandelbox knobs, written for `w`, `color_mode`, `precision`); every group has a
heading tooltip (Fractacular's `group_tooltips()` plus Render).

### The shader and the estimator

`mandelbox.gdshader` gains one uniform per catalogue id, named exactly as the
id (Fractacular's convention), replacing `scale`, `min_r2`, `fixed_r2`,
`julia_enabled` and `julia_point`. One function does the iteration for both
`de()` and `field()`:

```glsl
// One Mandelbox iteration on the 4D orbit point z with running derivative dz.
void mb_step(inout vec4 z, inout float dz, vec4 c) {
	if (fold_order == 0) { z = mb_box_fold(z); mb_sphere_fold(z, dz); }
	else                 { mb_sphere_fold(z, dz); z = mb_box_fold(z); }
	if (rotating) { z = mb_iter_rotate(z); }
	z = box_scale * z + c;
	dz = dz * abs(box_scale) + 1.0;
}
```

with `mb_box_fold`, `mb_sphere_fold`, `mb_iter_rotate` and `mb_rot_plane`
ported from Fractacular's `mandelbox.gdshader` and `common.gdshaderinc`
(`rotating` is computed once per fragment). `de(p)` starts from
`z = vec4(p, w)` and `c = per-component (julia_i || julia_all) ? c_i : z0_i`,
returns `length(z) / abs(dz)`; `field()` (the Ice Fractal look) runs the same
step from `z = 0`, `c = vec4(q, w)`, ignoring `dz`, and returns `length(z) − 8`.
The noise call sites, the normals, the march and the colour modes are
untouched.

`dz = dz·|s| + 1` is Fractacular's derivative. Today's `dz = −dz·s + 1` equals
it for every negative scale, which is every scale the site allows and every
fixture in `distance_estimator_test.gd`, so the 24 fixtures hold unchanged;
for positive scales the new form is the standard one.

`DistanceEstimator.estimate_at()` mirrors `mb_step` in 64-bit scalars
(`zx, zy, zz, zw`), reading the new `FractalParams` fields, with the rotation
as six plane rotations in the shader's order. A new fixture set pins the
non-default knobs: a positive scale, Sphere → Box, one iteration rotation, a
non-zero `w`, and a per-component Julia mix, each checked against the shader
through the existing `shader_test.gd` readback (or, where headless cannot
read pixels, against values computed once by hand in the test).

### FractalParams: resolved values

`FractalParams` keeps its role as the object every consumer reads, but the
shape fields are now the **resolved** values, written once per frame by the
resolver, and are renamed to the catalogue ids: `box_scale`, `fold_limit`,
`min_radius`, `fixed_radius`, `fold_order`, `w`, `julia_all`, `julia_0..3`,
`c_0..3`, `iter_rot_xy..zw`, `color_mode`, `precision`. Two helpers keep the
marker and the orbit camera simple: `julia_point() -> Vector3` (`c_0..2`) and
`julia_enabled() -> bool` (`julia_all`). The renderer and preference fields
(`fast_controls`, `camera_mode`, `mouse_sensitivity`, `detail`, `detail_range`,
`detail_falloff`, `max_steps`, `min_render_scale`) stay as they are, edited
directly by the settings menu.

`apply_resolved(values: Dictionary)` sets every listed field without the
per-field setters and emits `changed` once, only if something differed. So a
view with no active binding costs no signal per frame; one bound to Time
changes every frame, which is what the governor should see (it is animating).
Nothing else writes the shape fields any more: the Julia marker's drag writes
`c_0..2` into the **table** (through `AttributeTable.set_default`), so the
drag survives the next resolve.

### Axes, keymap, clock

`Axes` holds an ordered list of `Axis { id: StringName, label: String,
speed: float, value: float }`. `step(id, direction, delta)` adds
`direction × speed × delta`; `set_value` is for loads and game code; `values()
-> Dictionary` feeds the resolver; `changed` fires on any edit. Values are
unbounded floats.

`Keymap` owns the `Axes` and maps each axis to a key pair. Keys are physical
keycodes, stored by name (`OS.get_keycode_string`, parsed back with
`OS.find_keycode_from_string`), so the file is readable and layout-independent:

```json
{
	"version": 1,
	"axes": [
		{"id": "a", "label": "Axis A", "speed": 1.0, "positive": "E", "negative": "Q"}
	]
}
```

That is the default keymap shipped as `saves/keymap.json`: one axis on Q/E at
one unit per second, so binding a slider to Axis A gives Q and E that slider
with the row's gain as its sensitivity. Loading goes through the same directory
logic as views (`WorkspaceFiles.directory()`; an export reads and writes
`user://saves/keymap.json`), and a missing or malformed file yields the default
with a warning.

For each axis the keymap registers two `InputMap` actions, `axis_<id>_pos` and
`axis_<id>_neg`, and keeps their events equal to the pair; rebinding erases and
re-adds the events. This is why tests can drive an axis with
`TestCase.hold(&"axis_a_pos", seconds)` like any other action, and why key
reading needs no special code.

The rebind API, all on `Keymap`, each emitting `changed` so the Movement pane
refreshes:

| call | what it does |
|---|---|
| `load_file(path) -> {ok, warnings}` / `save_file(path) -> Error` | the JSON above; `path` defaults to the shipped file |
| `add_axis(id, label, speed, positive, negative)` / `remove_axis(id)` | ids are unique; removing an axis leaves bindings to it inert (they resolve to the default) |
| `bind(id, positive: Key, negative: Key)` | either may be `KEY_NONE` |
| `set_speed(id, units_per_second)` | |
| `axes() -> Axes` | the values, for the resolver and for saves |

`AxisController` (a Node) reads `Input.get_action_strength` for every pair in
`_process` and steps the axes, except while a text field has keyboard focus in
any of the viewports it is given (the main window's and the console's), so
typing "e" into a spin box never moves an axis. The same rule is applied to
`FlyCamera.move_direction()`, since with a native console the main window's
input state still sees every key: a small `TextFocus.any(viewports)` helper
serves both.

`Clock` is `t`, advanced in `_process` from 0 when the Main scene opens. The
tree pause pauses it. It is not saved.

### The console window

`ConsoleWindow extends Window`, title "Console", 1000×700, minimum 700×400,
resizable, hidden at start. It is native because the project sets
`display/window/subwindows/embed_subwindows = false`; that makes the noise
editor's window native too, which is a gain (two monitors), and on the web the
setting is ignored, so both fall back to embedded windows. Its contents are an
`HSplitContainer`: the Shape pane left, the Movement pane right, split
remembered for the session only.

**Shape pane** — `AttributeInspector`: a `ScrollContainer` of group headings
(label + heading tooltip) and one `AttributeRow` per spec, built once from the
table at setup. `AttributeRow` is the port of Fractacular's wide row:

```
[label (log)]  [slider ──── spin]   [source ▾] [gain] [wave ▾] [period]
               [ min   mid    max ]           (log rows only)
               [→ 1.234 ]                     (while a binding is active)
```

BOOL rows show a CheckBox, ENUM rows an OptionButton, neither with binding
widgets. `show_when` collapses the `c_i` rows unless their toggle or
`julia_all` is on. The source dropdown lists None, Time, then every axis by
label, rebuilt when the keymap changes; a binding to an axis that no longer
exists shows as "(missing: id)" and keeps its stored source so the keymap can be
fixed without losing the binding. Every edit goes to the table; the row
re-reads itself on `changed`. `set_resolved(values)` is called each frame by
the console so bound rows' readouts move.

**Movement pane** — one line per axis: label (editable), id, value readout, a
"0" button that zeroes the value, speed spin, two `KeyCaptureButton`s (click,
then press a key; Escape cancels; the button shows the key name), and a remove
button; an "Add axis" button; below, the clock readout and the fly camera's
speed factor readout (which left the Q panel); and a strip of **Save** (writes
the current keymap path), **Save as…** and **Load…** (native panels through a
`WorkspaceFiles` with `subdir = ""` filtered to `keymap*.json`). The pane is a
view over `Keymap`: it writes through the API above and refreshes on `changed`.

**Toggle and the mouse.** `CtrlTap` is the arm/disarm detector from the
`quick-controls` branch, factored out: a bare non-echo Ctrl key-down arms, any
other key-down while armed disarms, a Ctrl key-up while armed fires. Main runs
one against the main window, the console runs one against its own window (a
native window gets its own key events) and emits `toggle_requested`. The rule
Main applies on a tap:

- Mouse captured (Fly mode, flying): free the mouse and make sure the console
  is open. The console on the other monitor is now clickable.
- Mouse free: toggle the console; when that closes it, recapture (Fly mode,
  not paused, noise editor closed).

A click in the view while the mouse is free recaptures it, closes the noise
editor as today, and **leaves the console open** — that is the point of a
second window. So capture is `fly and not paused and noise closed and not
_free_requested`, and the console's visibility no longer gates it. Escape
pauses as before; the console stays where it is.

### What the Q panel held

The `ControlsPanel` scene and script are deleted along with their test. Its
contents go:

| was in the panel | goes to |
|---|---|
| the four shape sliders, Colour, Precision, Julia + X/Y/Z | the console's Shape pane (as the catalogue above) |
| Save / Load, the current file name, the status line | the **pause menu**, as a Save view… / Load view… row with the name beside it and the status line under the buttons |
| Noise editor… | the pause menu (opens the editor and resumes) |
| Camera: Fly / Orbit | the pause menu, an option row |
| Fast Controls | already on Settings → Renderer |
| Mouse sensitivity | already on Settings → Controls |
| speed ×n readout, the key legend | the Movement pane; the README |

Cmd+S / Ctrl+S quick save and Cmd+P / Ctrl+P screenshot stay as they are.
`_on_prompting` (a file panel opening while captured) frees the mouse without
opening anything.

### Saved views: version 2

```json
{
	"version": 2,
	"shape": {
		"defaults": {"box_scale": -2.09, "fold_limit": 1.0, "...": "every catalogue id"},
		"bindings": {"box_scale": {"source": "a", "gain": 0.5, "waveform": "LINEAR", "period": 4.0}}
	},
	"axes": {"a": 0.0},
	"fractal": {"fast_controls": true, "camera_mode": "fly", "mouse_sensitivity": 0.1,
	            "detail": 1.0, "detail_range": 10.0, "detail_falloff": 0.0,
	            "max_steps": 128, "min_render_scale": 0.25},
	"camera": {"eye": [], "forward": [], "up": [], "speed_factor": 1.0},
	"noise": {}
}
```

`shape` is `AttributeTable.to_dict()` (only active bindings are written);
`axes` is every axis value by id; `fractal` keeps the keys that are not shape
knobs. The clock is not saved. Loading is additive and warning-based as today:
unknown shape ids and unknown axis ids warn and are skipped (an axis value for
an axis the keymap lacks is dropped with a warning, since there is nothing to
hold it).

A version-1 file still loads: the loader maps `scale` → `box_scale`,
`inner_radius` → `min_radius`, `outer_radius` → `fixed_radius`,
`julia_enabled` → `julia_all`, `julia_point` → `c_0..2`, and the rest of its
`fractal` keys to where they now live, without a warning. Saving always writes
version 2. The four files in `saves/` are rewritten to version 2 once, after
the renderer-options work has landed (it edits the same files).

The keymap is deliberately **not** in the view: a level will load a view and a
keymap, and the same view can be played under different key pairs.

### Main's wiring

`Main._ready` builds, in order: the `AttributeTable` from `MandelboxShape`,
the `Keymap` (loads `saves/keymap.json`), the `AxisController`, the `Clock`,
the `ConsoleWindow` (given the table, the keymap and the clock), then the
existing view, cameras, marker (given the table), governor, pause menu and
noise window. In `_process` it resolves:

```gdscript
var values := BindingResolver.resolve(_table, _keymap.axes().values(), _clock.t)
params.apply_resolved(values)
if _console.visible:
	_console.set_resolved(values)
```

Resolving every frame is cheap (about thirty scalars); doing it only on change
would need the table, every axis and the clock to be watched, for no gain. The
governor keeps watching `params.changed` and `camera.changed`.

## Testing

Headless, in `tests/`, following `test_case.gd`:

- `attribute_test.gd` — spec make/sanitize (wrap, clamp, INT, ENUM fallback),
  table defaults and bindings, `to_dict`/`apply_dict` round trip with unknown
  ids warned.
- `binding_test.gd` — resolver: inactive and non-bindable return the default;
  Time, an axis, a missing axis (raw 0); the three waveforms at known points;
  sanitize applied.
- `axes_test.gd` — step and set_value; keymap JSON round trip, default on a
  missing file, key names; InputMap actions exist and follow `bind()`;
  `add_axis`/`remove_axis`; the controller moves an axis under
  `hold(&"axis_a_pos", 0.5)` and not while a LineEdit has focus.
- `mandelbox_shape_test.gd` — every spec has tooltip and effects, defaults in
  range, ids unique, every group has a heading tooltip, and the shader's
  uniform set equals the catalogue ids plus the renderer-owned uniforms (the
  Fractacular `technique_schema_test` check, which `shader_test.gd` partly
  does today).
- `distance_estimator_test.gd` — the 24 fixtures unchanged, plus the
  non-default fixtures above.
- `fractal_params_test.gd` — `apply_resolved` emits once and only on a
  difference; the renamed fields; `julia_point()`.
- `workspace_test.gd` — version 2 round trip including bindings and axes; a
  version-1 file maps its keys; unknown ids warn.
- `console_test.gd` — the window builds both panes; a row edit lands in the
  table; the source dropdown lists the axes and updates on `Keymap.changed`;
  the readout follows `set_resolved`; the Movement pane adds, rebinds and
  removes an axis through the API and the key-capture button; Ctrl tap in the
  console emits `toggle_requested`.
- `main_test.gd` — a Ctrl tap while captured frees the mouse and opens the
  console; a tap while free closes it and recaptures; a click in the view
  recaptures and leaves the console open; a bound axis changes
  `params.box_scale` after a `hold`; Q and E are the default axis; the pause
  menu's Save/Load/Camera/Noise controls do what the panel's did; WASD does not
  move the camera while a console text field has focus.
- `menus_test.gd` — the new pause menu rows.

`tests/screenshots.sh` keeps `default_view.png` identical to today's (every
knob at its default), and adds `console_bound_axis.png`: Axis A bound to
`box_scale` with gain 0.5, `axis_a_pos` held for one second, the picture
required to differ from the default.

## Follow-ups this leaves open

- Binding rows on noise-node parameters (unify `NoiseParamSpec` with
  `AttributeSpec`).
- A level format: which view and which keymap to load, and when.
- Clock controls, if a Time binding ever needs pausing.
- Fractacular's 2D slice panels of the live 3D shape, with the camera as the
  ring.
