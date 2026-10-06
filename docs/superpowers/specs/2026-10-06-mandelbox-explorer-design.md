# Mandelbox explorer — design

A Godot 4.6 project, exported for the web, that reproduces the Mandelbox
viewer at <https://icefractal.com/mandelbox/> and adds a free-fly camera.
Every control the site has is here, reachable at runtime by pressing **Q**.
On top of that you can fly through the fractal: mouse to aim, **W/A/S/D** to
move forward, left, back and right relative to the camera, **Space** up and
**Shift** down relative to the camera.

The fractal algorithm, the camera and the panel are written fresh from the
site's observable behaviour. Nothing is copied from the site's source.

## Goals

- Same picture as the site for the same parameters: the default view, the
  four shape sliders, the thirteen colour modes, precision and Julia mode.
- A free-fly camera whose speed scales with distance to the fractal, so you
  can keep flying into detail without ever overshooting.
- The site's orbit camera as an alternative, switchable at runtime.
- Adaptive render resolution so flying stays smooth in WebGL, and zero GPU
  cost while the view is still.
- Headless tests for every piece of maths, and a windowed screenshot check.

## Non-goals

Save Image, Copy URL / load from URL, the High DPI toggle, a reset button,
touch controls, and any fractal other than the Mandelbox. None of these are
built. The structure should not make them hard to add later, but nothing is
designed around them.

## Engine and export

- Godot 4.6, **GL Compatibility** renderer (the only renderer the web export
  supports). `project.godot` declares features `"4.6", "GL Compatibility"`.
- GDScript only. No C#, even though the installed editor is the Mono build.
- Window: 1280×800 default, stretch mode `disabled` (the view fills the
  window at native pixels; resolution scaling is handled by the view itself).
- `export_presets.cfg` holds one **Web** preset with `variant/thread_support`
  off, so the page needs no cross-origin isolation headers. Exports go to
  `build/web/` which is git-ignored.
- Input actions in `project.godot`: `move_forward` (W), `move_back` (S),
  `move_left` (A), `move_right` (D), `move_up` (Space), `move_down` (Shift),
  `toggle_panel` (Q).
- `run.sh` launches the project (`./run.sh`, `./run.sh --editor`), modelled on
  Fractacular's: it refreshes the script class cache with a headless import
  when a script is newer than the cache.

## Coordinates and conventions

All positions are in **fractal coordinates**: the space the distance
estimator is evaluated in. The site evaluates its estimator at twice its
camera coordinates, so a site position `(x, y, z)` corresponds to our
`(2x, 2y, 2z)`.

**World up is +Z.** The site's default camera has its up vector pointing
mostly along +Z, and its heading rotates about Z, so Z is the natural up.

**Default camera** (matches the site's initial view exactly):

| quantity | value |
|---|---|
| eye | `(8.175847, 3.812460, 3.283393)` |
| looks at | the origin |
| vertical field of view | 40° |

The camera's basis is stored as a `Transform3D`: `basis.z` points *backward*
(Godot convention, forward is `-basis.z`), `basis.y` is up, `basis.x` is
right. The default basis is the look-at from the eye to the origin with +Z as
the up hint.

## Architecture

```
src/
  main.tscn / main.gd          wires everything, owns input mode (captured vs free)
  fractal/
    fractal_params.gd          Resource: every shape/colour/precision/Julia value, emits `changed`
    distance_estimator.gd      static CPU copy of the shader's estimator
    mandelbox.gdshader         the raymarcher, a canvas_item shader
    fractal_view.gd / .tscn    SubViewport + ColorRect(shader) + window-filling TextureRect
  camera/
    camera_state.gd            Resource: Transform3D + speed factor, emits `changed`
    fly_camera.gd              mouse-look + WASD/Space/Shift, distance-scaled speed
    orbit_camera.gd            the site's drag-to-orbit controller
    julia_marker.gd            draws and drags the Julia point on screen
  ui/
    controls_panel.gd / .tscn  the Q panel; edits FractalParams and camera settings
  perf/
    resolution_governor.gd     adaptive render scale and idle freeze
tests/
  test_case.gd                 headless test base (as in Fractacular)
  *_test.gd                    one per unit, listed under Testing
  run_all.sh                   runs every headless test
  screenshots.gd / .sh         windowed render check via `open -g`
docs/superpowers/specs/        this file
README.md                      how to run, the key table, the controls
```

Each unit has one job and talks to the others through two resources
(`FractalParams`, `CameraState`) and signals. The shader never knows about
the panel; the panel never knows about the shader.

### Data flow

```
ControlsPanel ──edits──▶ FractalParams ──changed──▶ FractalView (uniforms)
                                           └──────▶ DistanceEstimator (inputs)
FlyCamera / OrbitCamera ──edits──▶ CameraState ──changed──▶ FractalView (eye, basis)
                                                    └──────▶ JuliaMarker (projection)
FractalView.size  ◀──sets── ResolutionGovernor ◀──frame time, "is anything changing?"
```

`Main` decides which camera script is active (from `FractalParams.camera_mode`)
and whether the mouse is captured. Everything else is reactive.

## FractalParams

A `Resource` (`class_name FractalParams`) with exported fields. Every setter
emits `changed`. Defaults are the site's defaults.

| field | type | range | default | notes |
|---|---|---|---|---|
| `scale` | float | −5 … −0.5 | −2.09 | the Mandelbox scale, always negative here (the site labels this "Slice") |
| `inner_radius` | float | 0 … 1 | 0.7 | squared before use |
| `fold_limit` | float | 0 … 1 | 1.0 | box-fold limit |
| `outer_radius` | float | 0 … 1 | 1.0 | squared before use |
| `color_mode` | int | one of the ids below | 1 | |
| `precision` | float | > 0 | 0.000025 | hit threshold relative to distance travelled |
| `julia_enabled` | bool | | false | |
| `julia_point` | Vector3 | | `(-0.23, 1.512, 1.892)` | fractal coordinates |
| `fast_controls` | bool | | true | adaptive resolution on/off |
| `camera_mode` | enum | FLY, ORBIT | FLY | |
| `mouse_sensitivity` | float | 0.02 … 0.5 | 0.1 | degrees per pixel |

Colour mode ids, in the dropdown's order (ids match the site so a saved
number means the same thing):

| id | name | | id | name |
|---|---|---|---|---|
| 0 | Grayscale | | 5 | Blue |
| 1 | Ice Fractal | | 6 | Blue 2 |
| 2 | Borg | | 7 | Pink-Blue |
| 3 | Rainbow | | 16 | Ice Box |
| 4 | Rainbow 2 | | 9 | Ice Box 2 |
| 8 | Rainbow 3 | | 14 | Gold |
| 15 | Rainbow Metal | | | |

## Distance estimator

The Mandelbox estimator (Tom Lowe's formula) with a scalar derivative
carried in a fourth component. Inputs: point `p`, `scale` (negative),
`min_r2 = inner_radius²`, `fixed_r2 = outer_radius²`, `fold`, and the Julia
point `c` when Julia mode is on (otherwise `c = p`). Let `z = p`, `dz = 1`.
Repeat `N` times:

1. **Box fold** each component: `z = clamp(z, -fold, fold) * 2 - z`.
2. **Sphere fold:** `r2 = dot(z, z)`. If `r2 < min_r2`, `k = fixed_r2 / min_r2`;
   else if `r2 < fixed_r2`, `k = fixed_r2 / r2`; else `k = 1`. Then
   `z *= k`, `dz *= k`.
3. **Scale and add:** `z = scale * z + c`; `dz = -dz * scale + 1`.
   (Equivalently, carry `w` with `w = -w` then `w = scale * w + 1`.)

Result: `length(z) / abs(dz)`.

Two variants: **low precision** with `N = 16`, used by the first marching
phase, and **high precision** with `N = 32`, used by the second phase, by
normals, and by the CPU copy.

`DistanceEstimator` (GDScript, `static func estimate(p: Vector3, params: FractalParams) -> float`)
is the `N = 32` variant. It must give the same numbers as the shader; its
test pins it to values taken from the site's own estimator (which is the
same function, evaluated in a browser):

Defaults (`scale −2.09, inner 0.7, fold 1, outer 1`, no Julia):

| point | distance |
|---|---|
| (0, 0, 0) | 0 |
| (0.5, 0.5, 0.5) | 1.67e−15 |
| (1.2, −0.3, 0.8) | 4.536385e−5 |
| (2, 2, 2) | 1.84e−20 |
| (3, 0, 0) | 1.0000000 |
| (8.18, 3.81, 3.28) | 6.5655845 |
| (0.1, 0.9, 1.5) | 1.2707534e−5 |
| (−1.5, 1.5, −1.5) | 7.2696999e−3 |

Alternative shape (`scale −3, inner 0.5, fold 0.8, outer 0.9`, no Julia):

| point | distance |
|---|---|
| (0, 0, 0) | 0 |
| (0.5, 0.5, 0.5) | 3.9589733e−3 |
| (1.2, −0.3, 0.8) | 7.3684211e−2 |
| (2, 2, 2) | 0.69282032 |
| (3, 0, 0) | 1.4000000 |
| (8.18, 3.81, 3.28) | 7.1416315 |
| (0.1, 0.9, 1.5) | 1.2998357e−2 |
| (−1.5, 1.5, −1.5) | 3.5649260e−3 |

Defaults with Julia on at `(−0.23, 1.512, 1.892)`:

| point | distance |
|---|---|
| (0, 0, 0) | 4.9979908e−3 |
| (0.5, 0.5, 0.5) | 1.0887837e−2 |
| (1.2, −0.3, 0.8) | 4.5308936e−3 |
| (2, 2, 2) | 4.9979908e−3 |
| (3, 0, 0) | 8.0696204e−3 |
| (8.18, 3.81, 3.28) | 2.3521820 |
| (0.1, 0.9, 1.5) | 3.6647735e−3 |
| (−1.5, 1.5, −1.5) | 0.25217396 |

Tolerance: relative 1e−5, or absolute 1e−9 for values below 1e−6 (double
precision in GDScript versus the browser's doubles should agree far better
than that; the tolerance just guards against a differently ordered sum).

## Shader

`mandelbox.gdshader`, `shader_type canvas_item`, drawn on a `ColorRect`
that fills the SubViewport. All floats `highp` (Godot's default; WebGL 2
gives 32-bit floats).

Uniforms:

| uniform | from |
|---|---|
| `eye : vec3` | `CameraState` |
| `cam_right, cam_up, cam_forward : vec3` | `CameraState.basis` (forward = `-basis.z`) |
| `tan_half_fov : float` | `tan(20°)` |
| `aspect : float` | viewport width / height |
| `scale, min_r2, fixed_r2, fold_limit, precision : float` | `FractalParams` |
| `color_mode : int` | `FractalParams` |
| `julia_enabled : bool`, `julia_point : vec3` | `FractalParams` |
| `box_half : float` | 2.0, or 20.0 when Julia is on |

**Ray.** For the fragment at `uv ∈ [0,1]²`, `ndc = (uv − 0.5) * 2` with y
flipped so +y is up; `dir = normalize(cam_forward + ndc.x * aspect * tan_half_fov * cam_right + ndc.y * tan_half_fov * cam_up)`.

**Bounds.** The site only draws fragments inside an axis-aligned cube of
half-size 2 (20 in Julia mode) and so appears to clip the fractal to that
cube. We get the same picture from outside, and sensible behaviour inside,
by marching only within that cube: intersect the ray with the cube; if it
misses, output the background; otherwise start at `max(0, t_enter)` and
treat crossing `t_exit` as a miss. Distance travelled (`total`) is measured
from the eye, not from the cube entry, so precision behaves as on the site.

**March.** Two phases, one after the other, continuing from the same point:

1. Up to 96 steps with the low-precision estimator. Step by the estimate;
   stop when `d < precision * total * 2`. Record `n1` = the step index at
   the stop, or 96 if it never stopped.
2. Up to 32 steps with the high-precision estimator; stop when
   `d < precision * total`. Record `n2`, or 32.

`ce = (n1 + n2) / 128`. The second phase runs even when the first one
stopped (it refines the hit). A ray that runs out of steps without ever
meeting the threshold is **not** a miss: it is shaded with whatever `ce` it
reached, exactly as on the site (this is what draws the faint "dust" around
the fractal). The only miss is leaving the cube.

**Shading inputs.** Let `v` be the hit point and `e` the eye, both in
fractal coordinates, and `h = v / 2`, `eh = e / 2` (the site's half-scale
coordinates, which several formulas below use directly). `N(v)` is a
central-difference normal from the high-precision estimator with
`delta = precision * total * 40`:
`N = normalize((D(v+δx) − D(v−δx), D(v+δy) − D(v−δy), D(v+δz) − D(v−δz)))`.

**The "Ice Fractal" normal.** Colour modes 1–9 in non-Julia mode do not use
`N`. They use a normal from a *different* field, `F(q) = length(z) − 8`
where `z` is the 16-iteration Mandelbox orbit started from `z = 0` with
`c = q` and no derivative tracking. The site evaluates `F` at the half-scale
point for the base sample and at the full-scale point plus 0.01 for the
offset samples. **Replicate this exactly:**

```
lw = F(h)
NF = normalize((F(v + 0.01x) − lw, F(v + 0.01y) − lw, F(v + 0.01z) − lw) / 0.01)
```

It is not a true gradient, and that is what gives the site's look. In Julia
mode these modes use `N` instead.

**Lighting.** For whichever normal `n` a mode uses:
`lgt = abs(dot(n, normalize(2·eh − h)))`, then `lgt = 0.5·lgt + lgt^160 + 0.1`.
`base = vec3(lgt) * (−n * 0.25 + 0.75) + vec3(0, 0, 0.2)`.

**Colour modes.** `ce` as above. Output alpha is always 1.

| mode | normal | colour |
|---|---|---|
| 0 Grayscale | none | `vec3(1 − ce)` |
| 1 Ice Fractal | NF / N | `base * ((1−ce)+0.5, 2(1−ce)²+0.5, 5(1−ce)⁴+0.5)` |
| 2 Borg | NF / N | `base * (max(lgt·ce, 1−ce), max(ce, 1−ce), max(0.5·lgt·ce, 1−ce))` |
| 3 Rainbow | NF / N | `hue(q) * ce + 0.5·lgt`, `q = dot(h, h) / 4` |
| 4 Rainbow 2 | NF / N | `hue(q) * (1 − ce)`, `q = dot(h, h) / 4` |
| 8 Rainbow 3 | NF / N | `hue(q) * (1 − ce)`, `q = n.z · 0.5 + 0.5 − 0.1` |
| 5 Blue | NF / N | `base * (lgt·max(lgt·ce, 1−ce), lgt + avg, 1 − ce + lgt)`, `avg = mean(base)` |
| 6 Blue 2 | NF / N | mode 5 result `+ ce²` |
| 7 Pink-Blue | NF / N | `(1 − 2·ce·(lgt+0.5), avg·(1−ce), (1−ce)·(lgt+0.5))` |
| 9 Ice Box 2 | NF / N | `((1−ce)², 1 − 1.9·ce², 1.17 − ce²)` |
| 16 Ice Box | N | `clamp(((1−ce)², 1 − 1.9·ce², 1.17 − ce²), 0, 1) * (lgt + 0.5)` |
| 15 Rainbow Metal | N, view space | `lv = max(0, nv.z)⁴`; `n2 = normalize(nv + (0.5, 0.5, 0))`; `(n2 + 1) * 0.5 * (lv − 2·ce + 0.5)` |
| 14 Gold | N, view space | `lv = max(0, nv.z)⁴`; `(0.75 − ce) * 2 * (lv, lv², lv·ce)` |

"NF / N" means NF outside Julia mode, N in Julia mode. "View space" means
`nv = (dot(N, cam_right), dot(N, cam_up), dot(N, −cam_forward))`, so `nv.z`
is positive when the surface faces the camera. `hue(q)` is the six-segment
rainbow ramp: red→yellow→green→cyan→blue→magenta→red as `q` goes 0→1, each
segment one sixth wide, with `q` clamped to `[0, 1)`.

**Background.** White for modes 5 and 6, black otherwise.

## FractalView

A scene: `SubViewport` (transparent off, `render_target_update_mode`
driven by the governor) containing a `ColorRect` with the shader; and a
`TextureRect` filling the window with the SubViewport's texture, linear
filtered, `expand_mode` to fill. `FractalView.render_scale` (0.25 … 1.0)
sets the SubViewport size to `window_size * render_scale`, rounded to whole
pixels, and updates `aspect`. `FractalView.request_frame()` renders one
frame (`UPDATE_ONCE`); `FractalView.continuous = true/false` toggles
`UPDATE_ALWAYS` / `UPDATE_DISABLED`.

It also exposes `project(point: Vector3) -> Vector2` (window pixels, or
null when behind the camera) and `unproject(pixel: Vector2, depth: float) -> Vector3`
for the Julia marker and orbit centring. Both use the same ray maths as the
shader, so a test can round-trip them.

## Cameras

### CameraState

A `Resource` with `transform: Transform3D` and `speed_factor: float`
(default 1.0). Setting either emits `changed`. `eye`, `forward`, `right`,
`up` are convenience getters.

### FlyCamera

Active when `camera_mode == FLY`. Reads `CameraState`, writes it back.

- **Look.** Only while the mouse is captured. Relative mouse motion turns
  the camera: yaw about **world +Z** by `−dx · sensitivity` degrees, pitch
  about the camera's own right axis by `−dy · sensitivity` degrees, with
  pitch clamped so the forward vector never gets within 1° of ±Z. Roll is
  always zero: after each update the basis is rebuilt from the forward vector
  with +Z as the up hint.
- **Move.** Every physics frame, read the six actions. Direction is
  `forward·(fwd − back) + right·(right − left) + up·(up − down)` in
  camera axes, normalised when non-zero. Displacement is
  `direction · speed · delta`.
- **Speed.** `speed = clamp(D(eye), 1e-6, 20) · speed_factor` where `D` is
  the CPU estimator with the current params. So one second of travel covers
  about the distance to the nearest surface, and the closer you get the
  slower you go. The floor keeps you moving when you are touching or inside
  the surface; the ceiling keeps far-away flight sane.
- **Scroll wheel.** Up multiplies `speed_factor` by 1.25, down divides it,
  clamped to `[0.01, 100]`. The panel shows the factor.
- **Mouse capture.** Owned by `Main`: captured when the panel is hidden in
  FLY mode; released when the panel is shown or the mode is ORBIT. A left
  click on the view while the mouse is free in FLY mode hides the panel and
  recaptures. On the web, capture only works from inside an input event
  (pointer lock), which the click satisfies.

### OrbitCamera

Active when `camera_mode == ORBIT`. The mouse is never captured.

- Keeps a `center: Vector3` (initially the origin) and derives the
  transform from `center`, the current distance and orientation. Switching
  into ORBIT keeps the current transform and sets `center` to the point hit
  by a CPU march along the view's centre ray (or the origin if the march
  travels further than twice the current distance to the origin). Switching
  back to FLY keeps the transform as is.
- **Left-drag** rotates about `center`: horizontal motion turns about world
  +Z, vertical motion pitches about the camera's right axis, 0.5° per pixel
  scaled by `mouse_sensitivity / 0.1`. Pitch is clamped as in FLY mode.
- **Shift + left-drag** pans in the camera's right/up plane, moving both the
  camera and `center`, by `distance_to_center · 0.001` per pixel (the site's
  pan speed is one tenth of the eye-to-centre distance per 100 px).
- **Alt + left-drag**, or **right-drag**, moves the camera toward or away
  from `center` along the view axis by `distance_to_center · 0.005` per
  pixel of vertical motion.
- **Wheel** moves the camera toward the point under the cursor by
  `±distance_to_center · 0.1` per tick (toward on wheel-up).
- **Click** (press without drag) marches a CPU ray through the cursor; if it
  hits inside the cube and the hit is within twice the current distance to
  `center`, the hit becomes the new `center` without moving the camera.
  Otherwise `center` becomes the origin.

### JuliaMarker

A `Control` drawn over the view, visible only when `julia_enabled`. Draws
a small ring at `FractalView.project(julia_point)`. While the mouse is free,
pressing on the ring and dragging moves the point: each frame the point is
set to `unproject(mouse_pixel, depth)` where `depth` is the point's camera-
space depth at the start of the drag, so it slides in the plane facing the
camera. Updates `FractalParams.julia_point`, which the panel's X/Y/Z fields
follow.

## ControlsPanel

A `PanelContainer` anchored to the top-left, hidden by default, toggled by
**Q** (the `toggle_panel` action). Q is ignored while a text field in the
panel has keyboard focus, so you can type a value containing "q"; Escape or
Enter blurs the field. Contents, top to bottom:

1. **Scale** slider −5 … −0.5, step 0.01, with the value shown.
2. **Inner Radius** slider 0 … 1, step 0.01.
3. **Fold** slider 0 … 1, step 0.01.
4. **Outer Radius** slider 0 … 1, step 0.01.
5. **Color** option button, thirteen entries in the order listed above.
6. **Precision** line edit; a parsed positive float is applied on Enter or
   focus-out, anything else is ignored and the field reverts.
7. **Julia** check box; when checked, three line edits **X Y Z** appear.
8. **Fast Controls** check box (adaptive resolution).
9. **Camera** option button: Fly / Orbit.
10. **Mouse sensitivity** slider 0.02 … 0.5.
11. **Speed factor** read-only label (fly mode), e.g. `speed ×1.95`.
12. A key legend: `Q panel · WASD fly · Space/Shift up/down · wheel speed ·
    click to capture mouse`, and in orbit mode the drag legend.

Every widget writes to `FractalParams` or `CameraState` immediately and
reflects external changes (for example the Julia point moved by dragging).
The panel never touches the shader or the viewport.

## ResolutionGovernor

A `Node` that owns `FractalView.render_scale` and its update mode. Pure
logic lives in a testable inner function `step(frame_time: float, changing: bool) -> void`
with observable `scale` and `mode` (`CONTINUOUS`, `FINAL_FRAME`, `IDLE`).

- `changing` is true on any frame where `CameraState` or `FractalParams`
  emitted `changed`, or a drag is in progress.
- **Fast Controls on:**
  - While `changing`: mode `CONTINUOUS`. Keep an exponential moving average
    of frame time (α = 0.2). Target 1/30 s. If the average exceeds 1.2× the
    target, multiply `scale` by 0.8; if it is under 0.6× the target, divide
    by 0.8; clamp to `[0.25, 1.0]`; change at most once every 0.5 s.
  - On the first frame with `changing == false`: mode `FINAL_FRAME`: set
    `scale = 1.0`, request one frame.
  - Next frame: mode `IDLE`, updates disabled. Nothing renders until
    something changes.
- **Fast Controls off:** `scale` stays 1.0; the mode logic (continuous while
  changing, one final frame, then idle) is unchanged.

The governor never resizes the SubViewport while it is mid-frame; scale
changes apply at the start of the next frame.

## Main

`main.tscn`: `Main` (Node) with children `FractalView`, `JuliaMarker`,
`ControlsPanel`, `ResolutionGovernor`, and the two camera nodes. `main.gd`:

- creates the two resources and hands them to every child;
- enables exactly one camera node from `camera_mode`;
- owns mouse mode as described under FlyCamera;
- handles `toggle_panel`.

## Testing

Conventions follow Fractacular: a `TestCase` base (`extends SceneTree`,
`check`, `check_eq`, `check_approx`, `frames`, `finish`), one
`tests/<unit>_test.gd` per unit, run by `tests/run_all.sh` under
`godot4 --headless`. Every test must run headless.

| test | what it pins |
|---|---|
| `distance_estimator_test` | the 24 fixtures above; symmetry (`D(p) == D(−p)`); Julia point changes the result |
| `fractal_params_test` | defaults, ranges, that every setter emits `changed`, the colour id list |
| `fly_camera_test` | each of the six actions moves along the matching camera axis; combined input is normalised; speed equals `D(eye)·factor` within the clamps; wheel scales the factor by 1.25; yaw keeps the camera level, pitch is clamped |
| `orbit_camera_test` | rotation keeps distance to centre; pan moves camera and centre equally; zoom changes distance only; click re-centres onto a hit |
| `fractal_view_test` | `project` then `unproject` round-trips; the shader compiles headless (`load()` it and check `get_shader_uniform_list()` is non-empty and names every uniform in the table above; a broken shader yields an empty list); render scale sets the SubViewport size |
| `resolution_governor_test` | feed synthetic frame times: slow frames lower the scale, fast frames raise it, never outside `[0.25, 1]`, never twice within 0.5 s; stopping produces one `FINAL_FRAME` at scale 1 then `IDLE`; Fast Controls off keeps scale 1 |
| `controls_panel_test` | each widget writes its field; external changes update the widget; invalid precision text reverts |
| `main_test` | the scene instantiates headless; Q toggles the panel; camera mode switch enables the right node |

`tests/screenshots.sh` launches the app with `open -g -n -W` (never
stealing focus), runs `tests/screenshots.gd`, and writes
`screenshots/default_view.png` plus one PNG per colour mode. The check for
the default view: fewer than 60 % of pixels are black, and the mean colour
has blue as its largest channel (the site's default is unmistakably blue).
Results go to `tests/out/screenshots.txt` as PASS/FAIL lines.

A visual comparison against the site's own render is a manual step: the
README says where the reference screenshot lives
(`docs/reference/icefractal-default.jpg`, captured from the site during this design) so a
developer can eyeball them side by side.

## Risks and decisions

- **Float precision.** WebGL gives 32-bit floats. Deep zoom will break down
  at the same depth it does on the site. Accepted.
- **Cost of the "Ice Fractal" normal.** Four extra 16-iteration orbits per
  hit pixel plus six 32-iteration ones for `N`. This is what the site does
  and it is why Fast Controls matters. Accepted.
- **Pointer lock on the web** only works from a user gesture; the click-to-
  capture rule satisfies that.
- **Idle freeze.** When nothing changes, no frames render; the panel is a
  normal Control so it still redraws itself. If any future effect needs
  continuous rendering it must tell the governor it is "changing".
