# Debug Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Q controls panel with a second native "Console" window (Fractacular embedded): a Shape inspector of binding rows editing every Mandelbox knob, and a Movement pane of virtual axes driven by key pairs, with the panel's non-knob contents moved to the pause/settings menus.

**Architecture:** Port Fractacular's attribute/binding model (`src/attributes/`) and add a movement layer (`src/axes/`: axes, keymap with InputMap actions, axis controller, clock). `FractalParams` holds *resolved* knob values written once per frame by `BindingResolver` from an `AttributeTable` + axis values + clock. The shader and the CPU distance estimator both run one shared 4D Mandelbox step with per-component Julia, fold order, and six iteration rotations. A native `ConsoleWindow` (HSplit of Shape | Movement) is toggled by a Ctrl tap.

**Tech Stack:** Godot 4.6, GDScript only, GL Compatibility renderer, canvas_item raymarch shader. Headless tests subclass `tests/test_case.gd`.

## Global Constraints

- Work ONLY in worktree `/Users/adam/Godot/HelpImStuckInAFractal/.claude/worktrees/debug-console` on branch `debug-console`. Prefix every git command with `git -C <worktree>`; run Godot with `--path <worktree>`.
- `git commit` is fine in logical units. NEVER push/merge/rebase/cherry-pick/revert/am or touch a remote or another branch. NEVER run `rm -rf` or any recursive force delete (list it at the end of the report instead). Do not create another worktree or switch branches.
- Godot must never steal focus: `--headless` for tests/imports; `tests/screenshots.sh` (uses `open -g`) for the windowed check, run from the worktree.
- Every commit message ends with: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- After adding/renaming any `class_name` script or shader, refresh the cache: `godot4 --headless --import --path <worktree>`.
- Make `tests/run_all.sh` exit 0 before every commit. Tests follow `tests/test_case.gd` (check / check_eq / check_approx / frames / hold / press_action / finish).
- The spec's renderer-options prerequisite has NOT landed on this branch. `FractalParams` keeps only the original fields plus `mouse_sensitivity`, `fast_controls`, `camera_mode`; `SettingsMenu` has only one page (no tabs). Do NOT implement the LOD work. Keep the `fractal` save section generic (iterate a key list). Keep Fast Controls: put its checkbox on Settings (the single Controls page) since no Renderer tab exists — flag this.
- Spec: `docs/superpowers/specs/2026-10-07-debug-console-design.md`. Port sources under `/Users/adam/Godot/Fractacular` (read only, never modify).

---

## File structure

Created:
- `src/attributes/attribute_spec.gd`, `attribute_table.gd`, `binding.gd`, `binding_resolver.gd`
- `src/axes/axes.gd`, `keymap.gd`, `axis_controller.gd`, `clock.gd`
- `src/fractal/mandelbox_shape.gd`
- `src/ui/text_focus.gd`, `src/ui/ctrl_tap.gd`
- `src/ui/console/console_window.gd`, `attribute_row.gd`, `attribute_inspector.gd`, `movement_pane.gd`, `key_capture_button.gd`
- `saves/keymap.json`
- Tests: `tests/attribute_test.gd`, `binding_test.gd`, `axes_test.gd`, `mandelbox_shape_test.gd`, `console_test.gd`

Modified:
- `src/fractal/fractal_params.gd` (resolved fields, `apply_resolved`, `julia_point()`, `julia_enabled()`)
- `src/fractal/mandelbox.gdshader` (new uniforms, `mb_step`)
- `src/fractal/distance_estimator.gd` (4D step)
- `src/fractal/fractal_view.gd` (`_push_params` to new uniforms)
- `src/workspace/workspace.gd` (version 2 + v1 migration)
- `src/main.gd`, `src/main.tscn` (wiring; remove ControlsPanel)
- `src/ui/pause_menu.gd` (Save/Load/Camera/Noise rows + status)
- `src/ui/settings_menu.gd` (Fast Controls checkbox)
- `project.godot` (`display/window/subwindows/embed_subwindows=false`)
- `saves/*.json` (rewritten to version 2)
- Tests updated: `distance_estimator_test.gd`, `fractal_params_test.gd`, `shader_test.gd`, `workspace_test.gd`, `main_test.gd`, `menus_test.gd`
- `README.md`, `docs/viz/*` text only where it names keys / the Q panel

Deleted: `src/ui/controls_panel.gd` + `.tscn` + `.uid`, `tests/controls_panel_test.gd` + `.uid`.

---

## Task 1: Attributes module (spec, table, binding, resolver)

**Files:**
- Create: `src/attributes/attribute_spec.gd`, `src/attributes/attribute_table.gd`, `src/attributes/binding.gd`, `src/attributes/binding_resolver.gd`
- Test: `tests/attribute_test.gd`, `tests/binding_test.gd`

**Interfaces produced:**
- `AttributeSpec.make(d: Dictionary) -> AttributeSpec` — keys `id,label,type,default,tooltip,effects` required (NO `category`); optional `min,max,step,hard_min,hard_max,log,wrap,bindable,group,enum_labels,enum_values,show_when,enabled_when`. `Type { FLOAT, INT, BOOL, ENUM }`. Methods `is_shown(values)`, `is_enabled(values)`, `sanitize(value)`.
- `AttributeTable` extends RefCounted, `signal changed(id: StringName)`; `_init(spec_list)`, `has`, `spec`, `ids`, `get_default`, `set_default`, `defaults`, `binding`, `set_binding`, `notify_binding_changed`, `has_active_binding`, `to_dict`, `apply_dict`.
- `Binding` extends RefCounted: `source: StringName` (`&""` none, `&"time"` clock, else axis id), `gain: float`, `waveform: Waveform {LINEAR,SINE,TRIANGLE}`, `period: float`. `is_active()`, `duplicate()`, `to_dict()`, `from_dict(d)`.
- `BindingResolver.resolve(table, axis_values: Dictionary, t: float) -> Dictionary`; `resolve_value(spec, default, binding, axis_values, t)`; `waveform_value(raw, waveform, period)`.

**Port** from `Fractacular/src/fields/attribute_spec.gd` and `attribute_table.gd` with these changes: delete the `Category` enum, the `category` field/REQUIRED key, `make()`'s category line, `specs_in()`, `copy_category_from()`. Keep `make/sanitize/is_shown/is_enabled` identical. In `AttributeTable`, delete `has_time_binding` (TIME is now a StringName source), `specs_in`, `copy_category_from`; keep the rest. `duplicate()` must still deep-copy.

**Binding** (rewrite, source is a StringName):

```gdscript
class_name Binding
extends RefCounted
enum Waveform { LINEAR, SINE, TRIANGLE }
var source: StringName = &""
var gain: float = 1.0
var waveform: Waveform = Waveform.LINEAR
var period: float = 4.0
func is_active() -> bool: return source != &""
func duplicate() -> Binding:
	var b := Binding.new(); b.source = source; b.gain = gain; b.waveform = waveform; b.period = period; return b
func to_dict() -> Dictionary:
	return {"source": String(source), "gain": gain, "waveform": Waveform.keys()[waveform], "period": period}
static func from_dict(d: Dictionary) -> Binding:
	var b := Binding.new()
	b.source = StringName(str(d.get("source", "")))
	b.gain = float(d.get("gain", 1.0))
	var wi := Waveform.keys().find(str(d.get("waveform", "LINEAR")))
	b.waveform = (wi if wi >= 0 else Waveform.LINEAR) as Waveform
	b.period = maxf(float(d.get("period", 4.0)), 1e-6)
	return b
```

`AttributeTable.to_dict/apply_dict` are as Fractacular's (String keys, only active bindings written, unknown ids warned).

**BindingResolver** (rewrite per spec):

```gdscript
class_name BindingResolver
extends RefCounted
static func resolve(table: AttributeTable, axis_values: Dictionary, t: float) -> Dictionary:
	var out := {}
	for s in table.specs:
		out[s.id] = resolve_value(s, table.get_default(s.id), table.binding(s.id), axis_values, t)
	return out
static func resolve_value(spec: AttributeSpec, default_value, binding: Binding, axis_values: Dictionary, t: float):
	if binding == null or not binding.is_active() or not spec.bindable:
		return default_value
	var raw := 0.0
	if binding.source == &"time":
		raw = t
	elif axis_values.has(binding.source):
		raw = float(axis_values[binding.source])
	# unknown axis id -> raw stays 0.0 (shows the default)
	var value := float(default_value) + binding.gain * waveform_value(raw, binding.waveform, binding.period)
	return spec.sanitize(value)
static func waveform_value(raw: float, waveform: Binding.Waveform, period: float) -> float:
	var p := maxf(period, 1e-6)
	match waveform:
		Binding.Waveform.SINE: return sin(TAU * raw / p)
		Binding.Waveform.TRIANGLE: return 1.0 - 4.0 * absf(fposmod(raw / p + 0.25, 1.0) - 0.5)
	return raw
```

- [x] **Step 1: Write `tests/attribute_test.gd`.** Adapt `Fractacular/tests/attribute_test.gd`: drop the `category` arg (specs built with no category), drop `specs_in`/`copy_category_from`/`has_time_binding` assertions. Keep: `make` id→StringName, hard_min/max defaults, float clamp, wide hard range, wrap fold, INT round/clamp/step, BOOL/ENUM not bindable, ENUM keep/fallback, enum_values default to indices, show_when, table keeps specs, `ids()` ordered, `set_default` sanitizes + emits once + no-emit on same value, bindable rows have a Binding, `has_active_binding`, `duplicate` independent, `to_dict`/`apply_dict` round trip with an unknown id warned.
- [x] **Step 2: Write `tests/binding_test.gd`.** Resolver: unbound float/int return default; `&"time"` reads t; a known axis id reads `axis_values[id]`; a missing axis id yields raw 0 (→ default); non-bindable returns default; the three waveforms at known points (as Fractacular's binding_test); sanitize applied (clamp to hard_max, wrap angle). Use `axis_values` dict form, e.g. `resolve(table, {&"a": 1.5}, 0.0)`.
- [x] **Step 3: Create the four source files** (ports + rewrites above).
- [x] **Step 4: Import + run.** `godot4 --headless --import --path <worktree>` then `godot4 --headless --path <worktree> -s tests/attribute_test.gd` and `-s tests/binding_test.gd`. Expected: PASSED.
- [x] **Step 5: Commit** `feat(attributes): port Fractacular attribute/binding model (no Category, StringName sources)`.

---

## Task 2: Axes, keymap, clock, text-focus helper

**Files:**
- Create: `src/axes/axes.gd`, `src/axes/keymap.gd`, `src/axes/axis_controller.gd`, `src/axes/clock.gd`, `src/ui/text_focus.gd`, `saves/keymap.json`
- Test: `tests/axes_test.gd`

**Interfaces produced:**
- `Axes` extends RefCounted, `signal changed`. Inner data per axis: `{id: StringName, label: String, speed: float, value: float}` kept as an ordered Array of small objects or dicts. API: `add(id,label,speed)`, `remove(id)`, `has(id)`, `list() -> Array` (ordered), `label(id)`, `set_label(id,text)`, `speed(id)`, `set_speed(id,v)`, `value(id)`, `set_value(id,v)`, `step(id,direction,delta)` (adds `direction*speed*delta`), `values() -> Dictionary` (id→value), `clear()`.
- `Keymap` extends RefCounted, `signal changed`. Owns an `Axes`. `axes() -> Axes`; `pairs() -> Dictionary` (id → {positive:int, negative:int} physical keycodes); `add_axis(id,label,speed,positive,negative)`, `remove_axis(id)`, `bind(id,positive,negative)`, `set_speed(id,units)`, `set_label(id,text)`; `load_file(path:="") -> {ok,warnings}`, `save_file(path:="") -> Error`; `current_path`. Registers InputMap actions `axis_<id>_pos`/`axis_<id>_neg` and keeps their events equal to the pair.
- `AxisController` extends Node. `setup(keymap: Keymap, viewports: Array)`; `_process` reads `Input.get_action_strength` for each pair and `axes.step`, skipped entirely while `TextFocus.any(viewports)`.
- `Clock` extends Node. `var t: float`; advances in `_process` (respects tree pause via default process mode). Not saved.
- `TextFocus.any(viewports: Array) -> bool` — true if any viewport's focus owner is a LineEdit or TextEdit.

**`saves/keymap.json` (shipped default):**
```json
{"version":1,"axes":[{"id":"a","label":"Axis A","speed":1.0,"positive":"E","negative":"Q"}]}
```

**Key names:** `OS.get_keycode_string(keycode)` / `OS.find_keycode_from_string(name)`. `KEY_NONE` stores as `""`. Loading uses `WorkspaceFiles.directory()`; default path `res://saves/keymap.json` (editor) or `user://saves/keymap.json` (export). Missing/malformed file → default keymap + a warning.

**InputMap registration** (in `Keymap`): on `add_axis`/`bind`, for each of pos/neg: `var action := StringName("axis_%s_pos" % id)`; if not `InputMap.has_action(action)` add it; `InputMap.action_erase_events(action)`; if key != KEY_NONE, make an `InputEventKey` with `physical_keycode = key` and `InputMap.action_add_event(action, ev)`. On `remove_axis`, erase both actions. Emit `changed` after edits.

- [x] **Step 1: Write `tests/axes_test.gd`.** Cover: `Axes.step(&"a", +1, 0.5)` with speed 1 → value 0.5; `set_value`; `values()` dict. Keymap: `add_axis` then `InputMap.has_action(&"axis_a_pos")` and event's `physical_keycode` == the key; `bind` re-points events; `set_speed`; `remove_axis` erases the actions and leaves a binding to it inert (resolver returns default — exercise via `BindingResolver.resolve` with the removed id); JSON round trip (`save_file`/`load_file` to a `user://` temp) preserves id/label/speed/keys by name; a missing file yields the default axis `a` with a warning. Controller: build a Keymap with axis `a`, an `AxisController` in the tree, `await hold(&"axis_a_pos", 0.5)` moves the axis > 0; with a `LineEdit` `grab_focus()` in a viewport passed to the controller, a `hold` does NOT move it. Use a temp keymap path so the shipped file is untouched.
- [x] **Step 2: Run → fail** (classes absent).
- [x] **Step 3: Create the five source files + `saves/keymap.json`.** `Clock._process`: `t += delta` (process mode inherits; the tree pause stops it). `AxisController._process(delta)`: `if TextFocus.any(_viewports): return` then for each pair strengths and `step`.
- [x] **Step 4: Import + run** `tests/axes_test.gd` → PASSED.
- [x] **Step 5: Commit** `feat(axes): virtual axes, keymap with InputMap actions, clock, text-focus helper`.

---

## Task 3: FractalParams resolved fields

**Files:**
- Modify: `src/fractal/fractal_params.gd`
- Test: `tests/fractal_params_test.gd` (rewrite)

**Interfaces produced:**
- Fields renamed to catalogue ids: `box_scale`(−2.09), `fold_limit`(1.0), `min_radius`(0.7), `fixed_radius`(1.0), `fold_order`(int 0), `w`(0.0), `julia_all`(bool), `julia_0..3`(bool), `c_0..3`(floats −0.23,1.512,1.892,0.0), `iter_rot_xy,iter_rot_xz,iter_rot_xw,iter_rot_yz,iter_rot_yw,iter_rot_zw`(0.0), `color_mode`(int 1), `precision`(2.5e-5). Kept preference fields: `fast_controls`, `camera_mode`, `mouse_sensitivity`. Keep `CameraMode`, `COLOR_MODE_IDS`, `COLOR_MODE_NAMES`.
- `apply_resolved(values: Dictionary) -> void` — set every listed field WITHOUT per-field setters; emit `changed` once, only if something differed.
- `julia_point() -> Vector3` returns `Vector3(c_0,c_1,c_2)`. `julia_enabled() -> bool` returns `julia_all`.

Keep per-field `@export`/setters (for the catalogue defaults + direct settings edits) but `apply_resolved` writes backing state directly then emits once. Implementation sketch:

```gdscript
const RESOLVED_KEYS: Array[StringName] = [&"box_scale",&"fold_limit",&"min_radius",&"fixed_radius",&"fold_order",&"w",
	&"julia_all",&"julia_0",&"julia_1",&"julia_2",&"julia_3",&"c_0",&"c_1",&"c_2",&"c_3",
	&"iter_rot_xy",&"iter_rot_xz",&"iter_rot_xw",&"iter_rot_yz",&"iter_rot_yw",&"iter_rot_zw",&"color_mode",&"precision"]
func apply_resolved(values: Dictionary) -> void:
	var dirty := false
	for k in RESOLVED_KEYS:
		if not values.has(k): continue
		var v: Variant = values[k]
		if get(k) != v:
			set_block_signals(true); set(k, v); set_block_signals(false); dirty = true
	if dirty: emit_changed()
```
(Setters call `emit_changed`; blocking signals around `set()` keeps it to one emit. Verify `Resource.set_block_signals` suppresses `changed` — if not, write to a backing var map instead. Simplest robust form: store fields as plain `var` with explicit setters, and in `apply_resolved` assign the backing directly via `set`, guarding each setter with a `_suppress` flag.)

- [x] **Step 1: Rewrite `tests/fractal_params_test.gd`.** Defaults for every new field (box_scale −2.09, min_radius 0.7, fold_limit 1.0, fixed_radius 1.0, fold_order 0, w 0.0, julia_all false, c_0..3 = −0.23,1.512,1.892,0.0, iter_rot_* 0, color_mode 1, precision 2.5e-5). `COLOR_MODE_IDS`/names unchanged. `julia_point()` == Vector3(−0.23,1.512,1.892); `julia_enabled()` == false. `apply_resolved`: connect a counter to `changed`; apply a dict that differs → fires exactly once; apply the SAME dict again → does NOT fire; a partial dict sets only its keys.
- [x] **Step 2: Run → fail.**
- [x] **Step 3: Rewrite `fractal_params.gd`** with the new fields, `apply_resolved`, `julia_point()`, `julia_enabled()`.
- [x] **Step 4: Import + run** `tests/fractal_params_test.gd` → PASSED. (Other tests will be red until later tasks — that's expected.)
- [x] **Step 5: Commit** `feat(params): resolved Mandelbox knob fields, apply_resolved, julia helpers`.

---

## Task 4: Shape catalogue

**Files:**
- Create: `src/fractal/mandelbox_shape.gd`
- Test: `tests/mandelbox_shape_test.gd`

**Interface produced:**
- `MandelboxShape.specs() -> Array[AttributeSpec]` in inspector order, and `MandelboxShape.group_tooltips() -> Dictionary`. `MandelboxShape.catalogue_ids() -> Array[StringName]`. Build an `AttributeTable` via `AttributeTable.new(MandelboxShape.specs())`.

Specs per the spec table. Groups in order: **Box** (`box_scale` default −2.09, min −5 max 3, hard ±6; `fold_limit` 1.0, 0..3; `min_radius` 0.7, 0..2; `fixed_radius` 1.0, 0..4; `fold_order` ENUM default 0, labels ["Box → Sphere","Sphere → Box"]; `w` FLOAT 0.0, −4..4), **Julia** (`julia_all` BOOL; `julia_0..3` BOOL; `c_0..3` FLOAT defaults −0.23,1.512,1.892,0.0, −4..4, each with `show_when` = its own toggle or `julia_all`), **Iteration rotation** (`iter_rot_xy,xz,xw,yz,yw,zw` FLOAT 0, −180..180, wrap), **Render** (`color_mode` ENUM default 1 — thirteen modes using `FractalParams.COLOR_MODE_NAMES` as labels and `COLOR_MODE_IDS` as enum_values, not bindable; `precision` FLOAT 2.5e-5, 1e-6..1e-3, log). Copy Mandelbox tooltip/effects from `Fractacular/src/fields/techniques/mandelbox.gd` for the shared knobs; write new tooltip/effects for `w`, `color_mode`, `precision`. `group_tooltips()` = Fractacular's three (Box/Julia/Iteration rotation) plus a "Render" entry. Note: spec uses `show_when` (collapse), matching the row's visibility; Fractacular used `enabled_when` — follow the spec and use `show_when` for the `c_i` rows.

- [x] **Step 1: Write `tests/mandelbox_shape_test.gd`.** Build the table; assert: every spec has non-empty `tooltip` and `effects`; every default is in `[hard_min, hard_max]` (FLOAT/INT); ids are unique; every distinct `group` has an entry in `group_tooltips()`; the set of ids equals the expected 23 catalogue ids; `color_mode` default 1 and its enum_values == `FractalParams.COLOR_MODE_IDS`; `box_scale` hard range ±6; `iter_rot_xy` wraps; `precision` is log. Add the shader-uniform-set check here OR in shader_test (Task 6) — do it in shader_test.
- [x] **Step 2: Run → fail.**
- [x] **Step 3: Create `mandelbox_shape.gd`.**
- [x] **Step 4: Import + run** → PASSED.
- [x] **Step 5: Commit** `feat(fractal): Mandelbox shape catalogue (ports Fractacular specs, adds w/color_mode/precision)`.

---

## Task 5: Shader — 4D step, new uniforms

**Files:**
- Modify: `src/fractal/mandelbox.gdshader`
- Test: `tests/shader_test.gd` (update expected uniform set)

Replace uniforms `scale, min_r2, fixed_r2, julia_enabled, julia_point` with one uniform per catalogue id (exact names): `box_scale, fold_limit, min_radius, fixed_radius, fold_order (int), w, julia_all (bool), julia_0..3 (bool), c_0..3, iter_rot_xy..zw, color_mode (int), precision`. Keep `eye, cam_right, cam_up, cam_forward, tan_half_fov, aspect, box_half`. Keep the NOISE region and all colour-mode code, the march, normals, `box_intersect`, `hue`. Add ported fold/rotate helpers + one shared step:

```glsl
vec4 mb_box_fold(vec4 p) { return clamp(p, -fold_limit, fold_limit) * 2.0 - p; }
void mb_sphere_fold(inout vec4 p, inout float dr) {
	float r2 = dot(p, p);
	float mr2 = max(min_radius * min_radius, 1e-12);
	float fr2 = max(fixed_radius * fixed_radius, 1e-12);
	if (r2 < mr2) { float f = fr2 / mr2; p *= f; dr *= f; }
	else if (r2 < fr2) { float f = fr2 / max(r2, 1e-12); p *= f; dr *= f; }
}
vec4 fp_axis(int i){ if(i==0)return vec4(1,0,0,0); if(i==1)return vec4(0,1,0,0); if(i==2)return vec4(0,0,1,0); return vec4(0,0,0,1);} 
vec4 mb_rot_plane(vec4 p, int a, int b, float deg){ float r=radians(deg); float c=cos(r); float s=sin(r); vec4 ea=fp_axis(a); vec4 eb=fp_axis(b); float pa=dot(p,ea); float pb=dot(p,eb); return p - pa*ea - pb*eb + (pa*c-pb*s)*ea + (pa*s+pb*c)*eb; }
vec4 mb_iter_rotate(vec4 p){ p=mb_rot_plane(p,0,1,iter_rot_xy); p=mb_rot_plane(p,0,2,iter_rot_xz); p=mb_rot_plane(p,0,3,iter_rot_xw); p=mb_rot_plane(p,1,2,iter_rot_yz); p=mb_rot_plane(p,1,3,iter_rot_yw); p=mb_rot_plane(p,2,3,iter_rot_zw); return p; }
void mb_step(inout vec4 z, inout float dz, vec4 c, bool rotating){
	if (fold_order == 0){ z = mb_box_fold(z); mb_sphere_fold(z, dz); }
	else { mb_sphere_fold(z, dz); z = mb_box_fold(z); }
	if (rotating){ z = mb_iter_rotate(z); }
	z = box_scale * z + c;
	dz = dz * abs(box_scale) + 1.0;
}
bool mb_rotating(){ return (abs(iter_rot_xy)+abs(iter_rot_xz)+abs(iter_rot_xw)+abs(iter_rot_yz)+abs(iter_rot_yw)+abs(iter_rot_zw)) > 1e-6; }
```

`de(vec3 p, int iters)`: `vec4 z0 = vec4(p, w); vec4 c = vec4((julia_0||julia_all)?c_0:z0.x, (julia_1||julia_all)?c_1:z0.y, (julia_2||julia_all)?c_2:z0.z, (julia_3||julia_all)?c_3:z0.w); vec4 z=z0; float dz=1.0; bool rot=mb_rotating(); loop i<32, break at iters, mb_step(z,dz,c,rot); return length(z)/abs(dz) + noise_displace(p);`
`field(vec3 q)`: `vec4 z=vec4(0.0); vec4 c=vec4(q, w); float dz=1.0; bool rot=mb_rotating(); loop 16 iterations mb_step(z,dz,c,rot); return length(z) - 8.0 + noise_displace(q);` (dz ignored but passed).
The Julia-marker normal branch in `fragment()` currently reads `julia_enabled`; change to `julia_all`.

- [x] **Step 1: Update `tests/shader_test.gd`** expected list to: `eye, cam_right, cam_up, cam_forward, tan_half_fov, aspect, box_half, box_scale, fold_limit, min_radius, fixed_radius, fold_order, w, julia_all, julia_0, julia_1, julia_2, julia_3, c_0, c_1, c_2, c_3, iter_rot_xy, iter_rot_xz, iter_rot_xw, iter_rot_yz, iter_rot_yw, iter_rot_zw, color_mode, precision`. Also assert the set of *shape* uniforms (minus the renderer-owned `eye, cam_right, cam_up, cam_forward, tan_half_fov, aspect, box_half`) equals `MandelboxShape.catalogue_ids()`.
- [x] **Step 2: Run → fail** (uniform mismatch).
- [x] **Step 3: Edit the shader.**
- [x] **Step 4: Import + run** `tests/shader_test.gd` → PASSED (shader compiles, uniform set matches).
- [x] **Step 5: Commit** `feat(shader): shared 4D Mandelbox step with fold order, iter rotation, per-component Julia, w`.

---

## Task 6: Distance estimator — 4D step + FractalView push

**Files:**
- Modify: `src/fractal/distance_estimator.gd`, `src/fractal/fractal_view.gd`
- Test: `tests/distance_estimator_test.gd` (keep 24, add non-default fixtures)

Rewrite `estimate_at(px,py,pz,params)` to mirror `mb_step` in 64-bit scalars `zx,zy,zz,zw` starting from `z=(px,py,pz,params.w)`, `c` per-component `(julia_i||julia_all)? c_i : z0_i`. Fold order from `params.fold_order`. Rotation: six plane rotations in shader order (xy,xz,xw,yz,yw,zw) each `a'=a cos−b sin, b'=a sin+b cos` on the (axis_a,axis_b) components, only when any angle ≠ 0. `dz = dz*abs(box_scale) + 1.0`. Return `sqrt(zx²+zy²+zz²+zw²)/abs(dz)`. Keep `estimate(p: Vector3, params)` delegating with `p.x,p.y,p.z`.

Note the spec's derivative identity: today's 24 fixtures used `scale=-2.09`/`-3` (negative) where `dz=-dz·s+1 == dz·|s|+1`, so they hold unchanged. The new `julia` fixtures used `julia_enabled` on default point → now `julia_all=true`, `c_0..2=−0.23,1.512,1.892`, `c_3=0`, `w=0`: identical math, so those 8 hold too.

`FractalView._push_params` → push every new uniform: `box_scale, fold_limit, min_radius, fixed_radius, fold_order, w, julia_all, julia_0..3, c_0..3, iter_rot_*`, `color_mode`, `precision`, `tan_half_fov`, and `box_half = 20.0 if _params.julia_enabled() else 2.0`.

- [x] **Step 1: Add non-default fixtures to `distance_estimator_test.gd`.** Keep all 24 existing rows but rename the Julia block to set `j.julia_all=true; j.c_0=-0.23; j.c_1=1.512; j.c_2=1.892` (same expected values). Add a new block pinning: a positive scale (`box_scale=2.0`), Sphere→Box (`fold_order=1`), one iteration rotation (`iter_rot_xy=30`), a non-zero `w` (`w=0.5`), and a per-component Julia mix (`julia_0=true,julia_2=true`, c set). Compute each expected value ONCE from the CPU estimator and also assert it matches the shader via `shader_test`'s approach where possible; where headless cannot read pixels, pin the hand/CPU value with a comment that it was cross-checked. (Pragmatic: generate the expected numbers by running `estimate_at` once, paste them in, and additionally assert internal invariants: `fold_order` changes the result; a non-zero `w` changes it; symmetry breaks under rotation.)
- [x] **Step 2: Run → fail.**
- [x] **Step 3: Rewrite `distance_estimator.gd`; update `fractal_view.gd::_push_params`.**
- [x] **Step 4: Import + run** `tests/distance_estimator_test.gd` and `tests/fractal_view_test.gd` → PASSED. Also re-run `shader_test`.
- [x] **Step 5: Commit** `feat(fractal): 4D CPU estimator matching the shader; view pushes the new uniforms`.

---

## Task 7: Console UI (rows, inspector, movement pane, key capture, ctrl-tap, window)

**Files:**
- Create: `src/ui/ctrl_tap.gd`, `src/ui/console/attribute_row.gd`, `attribute_inspector.gd`, `movement_pane.gd`, `key_capture_button.gd`, `console_window.gd`
- Test: `tests/console_test.gd`

**Interfaces produced:**
- `CtrlTap` extends RefCounted (or a tiny helper): `feed(event) -> bool` returns true when a bare Ctrl tap fired; arms on bare non-echo Ctrl key-down (only when `not typing`), disarms on any other key-down, fires on Ctrl key-up while armed. Expose a `typing_guard: Callable` so Main can pass `text_field_has_focus`.
- `AttributeRow` extends HBoxContainer: `setup(spec, table)` (NO compact mode), `refresh()`, `set_resolved(value)`, accessors `value_control/spin_box/source_option/gain_spin/wave_option/period_spin/readout`. Source dropdown lists None, Time, then axes by label — `set_sources(axis_list: Array)` rebuilds its items (id stored per item), called on `Keymap.changed`; a stored source absent from the list shows "(missing: id)" and is preserved.
- `AttributeInspector` extends VBoxContainer: `setup(table, group_tooltips)`, builds group headings + one row per spec once; `set_resolved(values)`; `set_sources(axis_list)` forwards to rows; `row(id)`, `row_count()`.
- `MovementPane` extends VBoxContainer: `setup(keymap, clock, speed_source: Callable)`; one line per axis (label edit, id, value readout, "0" button, speed spin, two `KeyCaptureButton`s, remove button), "Add axis" button, clock readout, fly speed-factor readout, Save/Save as…/Load… strip through a `WorkspaceFiles` (`subdir=""`, filter `keymap*.json`, `quick_save_enabled=false`). Refreshes on `Keymap.changed`. Accessors for tests: `add_button()`, `rows()`/`axis_line(id)` exposing the widgets.
- `KeyCaptureButton` extends Button: shows a key name; click → "press a key…"; next physical key-down writes it (`key_captured(keycode)` signal); Escape cancels. `set_key(keycode)`.
- `ConsoleWindow` extends Window: title "Console", size 1000×700, min 700×400, resizable, hidden at start; `setup(table, keymap, clock, group_tooltips, speed_source)`; builds an `HSplitContainer` Shape|Movement; `signal toggle_requested`; `set_resolved(values)` forwards to the inspector; its own `CtrlTap` on key input emits `toggle_requested`; rebuilds inspector sources on `Keymap.changed`.

**Port** `AttributeRow` from `Fractacular/src/ui/attribute_row.gd` but **drop compact mode entirely** (no `_column/_line_one/_line_two`, no `compact` branch) and drop `is_value_enabled`/`enabled_when`-driven disabling if unused — keep `show_when` visibility. Change the source widget: instead of fixed `SOURCE_LABELS`, build items dynamically: item 0 "None" id `&""` (store StringName in metadata via `set_item_metadata`), item 1 "Time" id `&"time"`, then one per axis with `set_item_metadata(i, axis.id)` and text = axis label. On select, read metadata into `b.source`. Keep gain/wave/period and the log slider/ticks/readout machinery. Port `AttributeInspector` from Fractacular, simplified: one table (no focus/empty state needed — always shows the shape), headings from `group_tooltips`.

**Movement pane** is new (model its refresh/teardown pattern on `Fractacular/src/ui/movement_window.gd`).

- [x] **Step 1: Write `tests/console_test.gd`.** Build table from `MandelboxShape`, a `Keymap` with the default axis (temp path), a `Clock`, a `ConsoleWindow`; add to tree; `await frames(1)`. Assert: inspector `row_count()` == specs count; editing a row's spin writes the table (`row(&"box_scale").spin_box().value = 1.0` → `table.get_default(&"box_scale")` ≈ 1.0); the source dropdown lists None, Time, Axis A; after `keymap.add_axis(&"b","Axis B",1,KEY_NONE,KEY_NONE)` the dropdown gains "Axis B" (console refreshed on `Keymap.changed`); `set_resolved({&"box_scale": 1.23})` with an active binding shows the readout; Movement pane: pressing "Add axis" calls `keymap.add_axis` (axis count grows), a `KeyCaptureButton` capture writes the key (`bind` called), remove button removes the axis; a `CtrlTap` down+up fed to the console emits `toggle_requested`.
- [x] **Step 2: Run → fail.**
- [x] **Step 3: Create the six source files.** `godot4 --headless --import` after.
- [x] **Step 4: Import + run** `tests/console_test.gd` → PASSED.
- [x] **Step 5: Commit** `feat(ui): console window — Shape inspector of binding rows and Movement pane of axes`.

---

## Task 8: Workspace version 2 (+ v1 migration)

**Files:**
- Modify: `src/workspace/workspace.gd`
- Modify: `saves/default.json`, `juliaIceField.json`, `juliaIceTerraces.json`, `noiseRidges.json` → version 2
- Test: `tests/workspace_test.gd` (rewrite to v2)

`capture(table, axes, params, camera, noise)` writes:
```json
{"version":2,"shape": <table.to_dict()>, "axes": <axes.values by id>,
 "fractal": {"fast_controls":..,"camera_mode":"fly","mouse_sensitivity":..},
 "camera": {...}, "noise": {...}}
```
`fractal` keeps ONLY the non-shape preference keys (generic key list `FRACTAL_KEYS = ["fast_controls","camera_mode","mouse_sensitivity"]` — iterate it so the later LOD merge is a small diff). `shape` is `table.to_dict()` (only active bindings). `axes` is every axis value by id.

`restore(data, table, axes, params, camera)`: apply `shape` via `table.apply_dict` (unknown ids warn); apply `axes` (skip + warn a value for an axis the keymap lacks); apply `fractal` keys (as today, camera_mode by name). Loading is additive/warning-based.

`load_file` accepts version 2 natively, and **migrates version 1**: map `scale→box_scale`, `inner_radius→min_radius`, `outer_radius→fixed_radius`, `julia_enabled→julia_all`, `julia_point→[c_0,c_1,c_2]`, and route its other `fractal` keys (`fold_limit, color_mode, precision` into the shape defaults; `fast_controls, camera_mode, mouse_sensitivity` into `fractal`) — no warning for a v1 file. Saving always writes version 2. Keep `save_noise_file`/`load_noise_file` but bump their VERSION handling to accept 2 (and 1).

Because callers now pass a table + axes, update signatures: `save_file(path, table, axes, params, camera, noise:={})`, `load_file(path, table, axes, params, camera) -> {ok,warnings,noise}`, `capture(...)`, `restore(...)`.

- [x] **Step 1: Rewrite `tests/workspace_test.gd` for v2.** Round trip: build a table (from MandelboxShape) with a couple of edited defaults and one active binding (`box_scale` → axis `a`, gain 0.5), an `Axes` with `a`=0.0, params prefs, a camera; save; load into fresh table/axes/params/camera; assert defaults, the binding (source `a`, gain 0.5, waveform, period), the axis value, the `fractal` prefs and camera all restore with no warnings; the file has `version==2` and sections `shape/axes/fractal/camera`. Unknown shape id warns; unknown axis id (value for an axis the keymap lacks) warns + dropped. A hand-written version-1 blob migrates (`scale`→`box_scale` etc.) with no warning. Every committed save loads cleanly with no warnings. Noise key round-trips; absence → null.
- [x] **Step 2: Run → fail.**
- [x] **Step 3: Rewrite `workspace.gd`; rewrite the four `saves/*.json` to version 2** (keep the same shape/camera content, expressed as the new ids; `noiseRidges.json` keeps its `noise` section). Verify each new file parses and loads with no warnings via a quick `-s` harness or the test.
- [x] **Step 4: Import + run** `tests/workspace_test.gd` → PASSED.
- [x] **Step 5: Commit** `feat(workspace): saved view version 2 (shape table + axes), version-1 migration`.

---

## Task 9: Main wiring, pause menu, settings, delete Q panel

**Files:**
- Modify: `src/main.gd`, `src/main.tscn`, `src/ui/pause_menu.gd`, `src/ui/settings_menu.gd`
- Delete: `src/ui/controls_panel.gd` + `.tscn` + `.uid`; `tests/controls_panel_test.gd` + `.uid`
- Test: `tests/main_test.gd` (rewrite), `tests/menus_test.gd` (extend)

**Main._ready** builds in order: `AttributeTable` from `MandelboxShape`; `Keymap` (loads `saves/keymap.json`); `AxisController` (given keymap + `[main viewport, console viewport]`); `Clock`; `ConsoleWindow` (given table, keymap, clock, group_tooltips, a `speed_source` returning `camera.speed_factor`); then the existing view, cameras, marker (marker now reads `params.julia_point()`/`julia_enabled()`), governor, pause menu, noise window. Remove all ControlsPanel references.

**Main._process:** `var values := BindingResolver.resolve(_table, _keymap.axes().values(), _clock.t); params.apply_resolved(values); if _console.visible: _console.set_resolved(values)`.

**Julia marker drag** writes `c_0..2` into the TABLE: `_table.set_default(&"c_0", p.x)` etc. (so the drag survives the next resolve). `JuliaMarker` reads `params.julia_enabled()` and `params.julia_point()`. Give the marker the table (add `setup(params, camera, view, table)`), or route its writes through a Main callback.

**Ctrl tap rule (Main):** use a shared `CtrlTap` with `typing_guard = func(): return TextFocus.any([main_vp, console_vp])`. On a tap: if mouse captured → free the mouse and ensure the console is open; if mouse free → toggle the console, and if that closed it, recapture when `fly and not paused and noise closed`. The console's own `CtrlTap` emits `toggle_requested`, wired to the same handler. Capture rule: `fly and not paused and noise closed and not _free_requested`; the console's visibility no longer gates capture. A click in the view while free recaptures, closes the noise editor, and LEAVES the console open. Escape pauses as before.

**PauseMenu** gains (above Resume or in a controls block): a "Save view…" / "Load view…" row with the current file name beside it and a status line under the buttons (signals `save_requested`/`load_requested`, methods `show_file(name)`, `show_status(text)`); a "Noise editor…" button (signal `noise_requested` — Main opens the editor and resumes); a Camera option row Fly/Orbit (signal `camera_changed(mode)` / reads+writes `params.camera_mode`). Wire Main to these (replacing the old panel wiring). `_on_prompting` frees the mouse without opening the panel (no panel now) — keep it freeing the mouse.

**SettingsMenu** gains a "Fast Controls" checkbox writing `params.fast_controls` — but SettingsMenu edits the `Settings` autoload, not params. DECISION: Fast Controls lives on `FractalParams`, not `Settings`. Put the Fast Controls checkbox on the pause menu's controls block (it has `params`) rather than SettingsMenu (which only has `Settings`), OR give the pause menu a Fast Controls checkbox. Simplest faithful move: Fast Controls checkbox on the **pause menu** (it owns `params`). Flag this deviation (spec said Settings→Controls, but that tab edits Settings and Fast Controls is a params field).

**main.tscn:** remove the `ControlsPanel` node and its ext_resource.

- [x] **Step 1: Rewrite `tests/main_test.gd`.** Replace all `panel` usage. Assert: console starts hidden, fly enabled; a Ctrl tap while captured frees the mouse and opens the console; a Ctrl tap while free closes it and recaptures; Ctrl+chord (S, and the Ctrl+P sharp case) does not toggle; a click in the view recaptures and leaves the console open; a bound axis (`table` binding `box_scale`→`a` gain 0.5) changes `params.box_scale` after `await hold(&"axis_a_pos", 0.5)`; Q and E are the default axis (`InputMap.has_action(&"axis_a_pos")`, its event is E); save/load round-trips through the pause menu's Save/Load signals (set a knob, save, change it, load, restored); the pause menu Camera row switches mode; Noise button opens the editor and resumes; WASD does not move the camera while a console text field has focus (grab focus on a console LineEdit, assert `fly.move_direction()` or camera position unchanged). Keep the Settings-sensitivity and noise-save-embeds-graph checks adapted to the new save signature.
- [x] **Step 2: Extend `tests/menus_test.gd`** for the new pause-menu rows (Save/Load/Camera/Noise/Fast Controls present and wired). Keep the main-menu + settings-sensitivity checks.
- [x] **Step 3: Run → fail.**
- [x] **Step 4: Edit `main.gd`, `main.tscn`, `pause_menu.gd`, `settings_menu.gd`;** delete controls panel files + test (use plain `rm` on the named files, never `rm -rf`). Remove ControlsPanel `class_name` references everywhere.
- [x] **Step 5: Import + run** `tests/main_test.gd`, `tests/menus_test.gd`, and the whole `tests/run_all.sh` → exit 0.
- [x] **Step 6: Commit** `feat(main): wire console/axes/clock; move panel contents to pause menu; delete Q panel`.

---

## Task 10: project.godot — native subwindows

**Files:** Modify `project.godot`.

Add under `[display]`: `window/subwindows/embed_subwindows=false`. This makes both the console and the noise window native (a monitor each); headless and web fall back to embedded automatically, so tests are unaffected. Remove the now-unused `toggle_panel` input action only if nothing references it (CtrlTap reads the raw Ctrl key, so `toggle_panel` can stay or go — leave it to minimise churn, or delete it and update any doc). 

- [x] **Step 1:** Add the setting; `godot4 --headless --import`.
- [x] **Step 2:** Run `tests/run_all.sh` → exit 0 (confirm `noise_window_test` and `console_test` still pass under the embed fallback).
- [x] **Step 3: Commit** `chore(project): native subwindows (console + noise on their own windows; embed fallback headless/web)`.

---

## Task 11: Docs — README, systems viz text

**Files:** Modify `README.md`; `docs/viz/*` text only where it names keys or the Q panel.

Update README: controls table (Ctrl tap now opens the Console, not the panel; Q/E are the default Axis A; Shift sprint, Space/Backspace up/down), a new "Console" section (Shape inspector + binding model + Movement pane + keymap file), saved-view format v2 (shape table + axes + fractal + camera + noise), and the keymap file format. Update the systems viz text (in `docs/viz/panes/*.js` or data) only where it names keys or the Q panel — do NOT restructure the viz.

- [x] **Step 1:** Edit README sections. `grep -rn "Q panel\|controls panel\|toggle_panel\|Ctrl" README.md docs/viz` and fix each hit that is now wrong.
- [x] **Step 2:** Commit `docs: console, keymap, saved-view v2; update controls and keymap references`.

---

## Task 12: Screenshot pass

**Files:** Modify `tests/screenshots.gd` (add `console_bound_axis.png`). `tests/screenshots.sh` already uses `open -g` and `--path`; run it from the worktree.

`default_view.png` MUST stay the identical picture (every knob at its default → identical uniforms → identical image; verify `_check_default` still PASS). Add `console_bound_axis`: build a table, bind Axis A → `box_scale` gain 0.5, set the axis value as if `axis_a_pos` held one second (axis value = 1×1s = 1.0 → box_scale resolves to −2.09 + 0.5×1.0 = −1.59), resolve, `params.apply_resolved(values)`, render, save PNG, and REQUIRE it differs from the default view image (reuse the `_check_noise`-style diff: assert diff fraction above a threshold vs the default render).

- [x] **Step 1:** Add the `console_bound_axis` block to `screenshots.gd` (render default first, then the bound-axis render, diff them, PASS only if different).
- [x] **Step 2:** Run `GODOT_APP=/Applications/Godot_mono.app tests/screenshots.sh` from the worktree. Expected: `PASS default_view`, `PASS console_bound_axis`, one `PASS mode_*` per colour mode. Capture the log lines for the report.
- [x] **Step 3: Commit** `test(screenshots): console_bound_axis differs from the unchanged default view`.

---

## Self-review notes

- Spec coverage: attributes (T1), axes/keymap/clock (T2), params resolved (T3), catalogue (T4), shader (T5), estimator+view (T6), console UI (T7), saves v2 (T8), main/pause/settings + Q-panel removal (T9), native windows (T10), docs (T11), screenshots (T12). Follow-ups (noise bindings, level format, clock controls, 2D slices) are explicitly out of scope.
- Deviations to flag in the report: (a) Fast Controls checkbox goes on the pause menu (not Settings→Renderer, which doesn't exist on this branch; and Fast Controls is a params field, not a Settings field). (b) `c_i` row collapse uses `show_when` per the spec (Fractacular used `enabled_when`). (c) `embed_subwindows=false` makes the noise window native too (spec-intended gain); headless/web embed-fallback keeps tests valid. (d) `distance_estimator_test` non-default fixtures pinned from the CPU estimator and cross-checked against the shader where feasible; hand-verified invariants otherwise.
- Type consistency: `Binding.source` is a `StringName` everywhere; resolver takes `axis_values: Dictionary`; save signatures carry `(table, axes, params, camera)`.
