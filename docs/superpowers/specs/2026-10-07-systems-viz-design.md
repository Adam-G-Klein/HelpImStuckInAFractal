# Systems viz — design

An in-browser, pannable, zoomable set of diagrams and live figures that explain
what this project does: the rendering pipeline, how the Mandelbox shape is
built, what every dial and option changes, how the cameras and the resolution
governor behave. It is a port of the systems viz in the sibling project
`/Users/adam/Godot/spellfactory` (`docs/viz/`, its `/visualize` skill and
`tools/viz/check.mjs`), with one pane for this project.

Decisions already made with Adam (2026-10-07):

- **Vehicle:** port spellfactory's engine wholesale (`viz.js`, `viz.css`,
  `index.html`, `check.mjs`, `viz.sh`, the `/visualize` skill and its
  `reference.md`, the `viz` launch config). Dependency-free static page, works
  from `file://`.
- **Panes:** one pane, `mandelbox`, with the tabs listed below.
- **Interactivity:** full live ports. The figures run the real maths, ported
  line for line from the GDScript and the shader into JavaScript, with the
  real dials as sliders at their shipped defaults, and frame-by-frame steppers
  (Step / Back / Reset) wherever an algorithm is best felt.
- **Audience:** Adam, as the engineer. Code names and uniforms up front,
  formulas inline, every blurb links a `file:line`.

## Goals

- Someone who has read the README can open `./viz.sh` and, tab by tab, come
  away knowing how a pixel is produced, why the shape looks the way it does,
  what each panel row changes and where in the code each step lives.
- Every number in the viz comes from a port of the shipped code, never a
  re-derivation from memory. Where a port exists, a hover shows the values the
  real code would compute.
- Every tooltip links the line it describes at a pinned commit, verified by
  the checker.

## Non-goals

A second pane, engine changes beyond what porting needs, a WebGL rendering of
the fractal in the browser (the live figures are 2D slices and small CPU
renders), and any change to the Godot project itself other than the files
listed under *What is added*.

## What is added

| path | what |
|---|---|
| `docs/viz/index.html` | the page; title "Help I'm Stuck In A Fractal", repo `https://github.com/Adam-G-Klein/HelpImStuckInAFractal`, one `<script src="panes/mandelbox.js">` line |
| `docs/viz/viz.js`, `docs/viz/viz.css` | the engine, copied from spellfactory unchanged apart from its header comment naming this project. Pane content never goes in it |
| `docs/viz/panes/mandelbox.js` | the pane: pure data passed to `VIZ.pane({...})`, with the JS ports of the maths inside its figures |
| `tools/viz/check.mjs` | the checker, copied unchanged |
| `viz.sh` | `./viz.sh [pane-id[/tab]]`, copied unchanged |
| `.claude/launch.json` | the `viz` static-server config for the in-app browser (`autoPort`) |
| `.claude/skills/visualize/SKILL.md`, `reference.md` | the skill, with spellfactory's paths and docs (`SYSTEMS.md`, `HISTORY.md`, Soulgraft vocabulary) replaced by this project's (`README.md`, `docs/superpowers/specs/`) |
| `README.md` | a short *Systems viz* section: what it is, `./viz.sh`, the checker |

Everything is committed. `.claude/settings.local.json` stays untracked (add it
to `.gitignore`).

## The pane

```js
VIZ.pane({
  id: "mandelbox",
  short: "Mandelbox viewer",
  title: "Help I'm Stuck In A Fractal — how a pixel is made",
  subtitle: "...",
  commit: "<HEAD at the time the pane is written>",
  pinNote: "main, unpushed: links 404 until it is pushed",   // main is ahead of origin
  ctx: { ... }, kinds: { ... }, tabs: [ ... ],
});
```

`ctx` hues, named by meaning (kept consistent across tabs):

| ctx | hue | meaning |
|---|---|---|
| `state` | 1 blue | the two shared resources, `FractalParams` and `CameraState` |
| `input` | 2 orange | `Main`'s input dispatch, `ControlsPanel`, `WorkspaceFiles` |
| `camera` | 3 green | `FlyCamera`, `OrbitCamera`, `JuliaMarker` |
| `render` | 6 violet | `FractalView`, the SubViewport, the shader, `ResolutionGovernor` |
| `math` | 4 amber | `DistanceEstimator`, the shader's `de`, `field`, normals, colour |
| `files` | 5 pink | `Workspace`, `saves/*.json` |

`kinds`: `call` solid (calls · sets), `signal` dash (`changed` signal), `data`
dot (reads a value / a uniform).

Every tab's blurbs cite `src/...` lines, the design spec
(`docs/superpowers/specs/2026-10-06-mandelbox-explorer-design.md`) where a
decision is explained there, and the test that pins a value
(`tests/*_test.gd`) where one exists. File paths are declared once in an `F`
table at the top of the pane, as fog-sim does.

### Tabs

Ten tabs, one diagram each unless marked as a group. Tab labels in bold.

1. **Architecture** (graph). Zones: *INPUT* (`Main._unhandled_input`,
   `ControlsPanel`, `WorkspaceFiles`), *STATE* (`FractalParams`,
   `CameraState`), *CAMERAS* (`FlyCamera`, `OrbitCamera`, `JuliaMarker`),
   *RENDER* (`FractalView` → `SubViewport` → `ColorRect` + `mandelbox.gdshader`
   → `TextureRect`; `ResolutionGovernor`), *CPU MATHS* (`DistanceEstimator`),
   *FILES* (`Workspace`, `saves/`). Edges: the panel and cameras *edit* the
   resources; the resources' `changed` *signals* fan out to `FractalView`
   (uniforms), `JuliaMarker` (projection), `ControlsPanel` (refresh), `Main`
   (`_apply_mode`) and the governor (`mark_changed`); `FlyCamera` and
   `OrbitCamera` *read* `DistanceEstimator`; the governor *sets*
   `render_scale` and the update mode. Every node links its class line, every
   edge the line that makes the call or connects the signal.

2. **One input, one frame** (seq). Participants: input event, `Main`, the
   active camera, `CameraState`, `FractalView`, `ResolutionGovernor`,
   `SubViewport` (shader), `TextureRect`. Rows: the dispatcher's four steps in
   order (Q, Julia marker drag, click-to-capture, camera `handle_event`); an
   `alt` fragment FLY / ORBIT; `CameraState.changed` → `_push_camera` +
   `request_frame` and → `governor.mark_changed`; the `_physics_process`
   movement loop (`loop` fragment); then `_process`: `governor.step` →
   `set_render_scale` / `set_continuous` / `request_frame`; the SubViewport
   renders the shader at `window × render_scale`; the TextureRect stretches it
   to the window. A section band for *stopping*: FINAL_FRAME at scale 1, then
   IDLE, nothing renders.

3. **Building the shape, fold by fold** (live figure). A port of
   `DistanceEstimator.estimate_at` / the shader's `de`. A 2D view of the plane
   `z = 0` (slider for the plane height), the four shape sliders at their
   defaults (`scale −2.09`, `inner 0.7`, `fold 1.0`, `outer 1.0`), a Julia
   toggle with the shipped point. The user clicks a point `p`; the figure walks
   the orbit *stage by stage*: **box fold** → **sphere fold** → **scale and
   add**, Step / Back / Reset through up to 32 iterations, drawing where `z`
   is after each stage (a trail), the fold box (`±fold`) and the two spheres
   (`inner_radius`, `outer_radius`) as the geometry the stages act on, and a
   readout of `z`, `r2`, `k`, `dz` and the running `|z| / |dz|`. The three
   stages are listed across the top with their shader and GDScript lines, as
   fog-sim lists kernel stages. A second, hoverable sample cloud (a small grid
   of points) can be switched on to show the whole plane moving under one
   iteration. Note says it is a port and that the CPU copy runs in 64-bit
   scalars while the shader is float32, and why (`distance_estimator.gd`
   header).

4. **What each dial does** (live figure). A `160 × 160` heatmap of the
   distance estimate on a plane through the origin (axis chooser X-Y / X-Z /
   Y-Z plus an offset slider), shaded by `log(d)`, with the surface drawn as
   the set of cells under a threshold in ink. Sliders: *Slice (Scale)*
   (−5 … −0.5), *Inner Radius*, *Fold*, *Outer Radius* (0 … 1), *Precision*
   (changes the threshold only; shows it is not a shape parameter), *Julia*
   toggle and X/Y/Z. Preset buttons load the three files in `saves/` (values
   read from the JSON at port time and cited). Hover a cell for its `d`. A
   caption under each slider says in one sentence what it does to the shape
   (scale flips and stretches each fold; inner/outer set the sphere fold's
   dead zone and inversion radius; fold sets the box). The port recomputes on
   slider release and keeps a frame well under 16 ms (compute in a worker-free
   chunked loop if a full recompute exceeds that).

5. **Marching one ray** (live figure, stepper). The ray march from
   `fragment()`, ported. A 2D slice containing a draggable eye and a draggable
   aim point; the cube bounds (`box_half` 2, or 20 in Julia mode) drawn; the
   plane's DE heatmap faint behind. Step / Back / Reset walks the march:
   **box intersect** (start at `max(0, t_enter)`), **phase 1** (`de(p, 16)`,
   up to 96 steps, stop at `d < precision · total · 2`), **phase 2**
   (`de(p, 32)`, up to 32 steps, stop at `d < precision · total`), then
   **`ce = (n1 + n2) / 128`**. Each step draws the unbounding circle of radius
   `d` at the current point (the sphere-tracing picture) and the hop; hovering
   a step shows `total`, `d`, the threshold and which phase. Readouts: `n1`,
   `n2`, `ce`, hit / left the cube / ran out of steps. The *precision* slider
   shows steps shrinking and the "dust": a ray that exhausts its steps is
   still shaded by its `ce`. The stage list across the top cites the shader
   lines of each phase.

6. **Shading and the colour modes** (group: live figure + table). Figure:
   for a chosen mode (buttons for the thirteen), a swatch grid of the output
   colour over `ce` (x, 0 … 1) and `lgt` before shaping (y, 0 … 1), with the
   normal fixed facing the light, using the ported `hue`, lighting
   (`lgt = 0.5·lgt + lgt^160 + 0.1`, `base`) and the mode formula; a second
   small plot of the lighting curve. A **Render** button draws a `96 × 60`
   CPU render of the default view in that mode with the full port (march,
   normals, colour), on demand only (not per frame), so the port can be
   eyeballed against `screenshots/mode_<id>.png`. Table: id, panel name,
   normal used (`NF` outside Julia / `N` / view-space `N`), formula, background;
   each row tips to its shader line.

7. **The two normals** (live figure). Why modes 1 to 9 look the way they do
   outside Julia mode: `N` is a central difference of `de(·, 32)` with
   `delta = precision · total · 40`; `NF` is the gradient of the Ice Fractal
   field `F(q) = |z16| − 8` sampled at the half-scale base `h = v/2` and
   full-scale offsets `v + 0.01`. The figure shows the `F` field on the plane
   as a heatmap with `NF` arrows at surface samples beside the `N` arrows from
   the true estimator, so the mismatch is visible, with the spec's note that
   it is not a true gradient and is replicated on purpose.

8. **Cameras** (group: figure + table). Figure: the fly speed along the
   default centre ray, `speed = clamp(D(eye), 1e-6, 20) · speed_factor`,
   plotted against distance travelled toward the surface, with the
   `speed_factor` wheel (×1.25 per tick, clamped 0.01 … 100) as a slider; a
   small diagram of yaw about world +Z and pitch clamped 1° off ±Z with no
   roll (`MAX_FORWARD_Z`). Table: every orbit gesture with its constant and
   line (rotate `0.5°/px · sens/0.1`, pan `0.001 · dist / px`, dolly
   `0.005 · dist / px`, wheel `0.1 · dist` per tick toward the cursor, click
   re-centres on a CPU-march hit within `2 ×` the eye-to-centre distance, else
   the origin; `enter()` on switching modes), plus the Julia marker drag (slides
   in the plane facing the camera at the captured depth).

9. **Resolution governor** (live figure, stepper). The three modes as a small
   state graph (CONTINUOUS / FINAL_FRAME / IDLE) with the transitions labelled
   from `step()`, and a stepper that feeds the ported `step(frame_time,
   changing)`: a *frame time* slider (ms), a *changing* toggle, a *Fast
   Controls* toggle, Step / Run / Reset, and a strip chart of `scale`, `mode`,
   the EMA and the cooldown per frame. Hover a frame for its numbers. The
   note cites the targets: `1/30 s`, EMA α 0.2, step ×0.8, clamp 0.25 … 1,
   cooldown 0.5 s.

10. **Dials, uniforms, saves and gotchas** (group: table + cards). Table: every
    panel row → `FractalParams` field (range, default) → shader uniform and
    the transform between them (`inner_radius² → min_r2`, `outer_radius² →
    fixed_r2`, `julia_enabled → box_half 2 / 20`, `tan_half_fov` constant,
    `aspect` from the viewport) → what it changes, each row tipping to
    `_push_params` and the panel line. Cards: *invariant* — CPU estimator
    equals the shader (the 24 fixtures), `project`/`unproject` round-trip,
    `COLOR_MODE_IDS` match the site; *gotcha* — fractal coordinates are twice
    the site's, world up is +Z, forward is `−basis.z`, Q is ignored while a
    text field has focus, Cmd/Ctrl suppresses movement so Cmd+S is a save,
    pointer lock needs a click on the web, float32 limits deep zoom, the
    `DistanceEstimator` runs scalars for 64-bit; *history* — the save file
    format (`version`, `fractal`, `camera` with eye / forward / up / speed
    factor; unknown keys skipped with a warning; exports write to
    `user://saves/`); *open* — the spec's non-goals (Save Image, URL state,
    High DPI, reset, touch).

### The ports

All ports live inside `panes/mandelbox.js`, each in one small named function
next to the figure that uses it, with a comment naming the source file and
lines:

| port | source |
|---|---|
| `de(p, iters, P)` | `src/fractal/mandelbox.gdshader` `de`, equal to `src/fractal/distance_estimator.gd` `estimate_at` |
| `field(q, P)` | the shader's `field` |
| `calcNormal`, `calcNF` | `calc_normal`, `calc_nf` |
| `hue`, `shade(mode, ce, lgt, n, ...)` | `hue` and the `fragment()` colour branches |
| `boxIntersect`, `march(eye, dir, P)` | `box_intersect` and the two phases of `fragment()` |
| `flySpeed` | `fly_camera.gd` `current_speed` |
| `governorStep` | `resolution_governor.gd` `step` |

The DE port is checked against the spec's fixture tables at load time: the
pane computes the 24 fixtures (`defaults`, `alternative shape`, `Julia`) and
pushes a visible error through `VIZ.errors` style reporting (a card in tab 10
turning red, and a `console.error`) if any differs beyond the test's
tolerance (relative 1e−5, or absolute 1e−9 below 1e−6). This is the viz's own
guard that its figures show the real shape.

## Verification

All three, as the skill demands, before the work is called done:

1. `node tools/viz/check.mjs --print --pane mandelbox` exits 0, and every
   printed line is read to confirm it is the line the tooltip describes.
2. In the in-app browser (`preview_start` with `viz`): every tab opened by
   `#mandelbox/<n>`, `VIZ.errors` empty after the last, a screenshot of every
   tab (and each block of a grouped tab) inspected for overlaps and clipped
   text; hover checked on a node, an edge, a table row and a figure element.
3. Live figures: `VIZ.frameMs` well under 16 ms on each; ~0 on a tab with no
   live figure; every control does what its label says; the DE fixture check
   passes; the on-demand colour render of mode 1 is unmistakably blue like
   `screenshots/default_view.png`.

`./viz.sh` and `./viz.sh mandelbox/5` open the page in the default browser.

## Risks and decisions

- **Engine fidelity.** The engine is copied, not re-implemented, so every
  block type behaves as in spellfactory and the skill's reference stays true.
  If a port needs something the engine lacks, the figure API's `el`/`image`
  cover it; no engine change is planned.
- **Cost of the heatmaps.** `160²` cells × 32 iterations is ~0.8 M fold
  steps per recompute, fine in JS; recompute only on control change, never per
  frame. The on-demand render in tab 6 is the only heavy port and runs on a
  button.
- **Links 404 until pushed.** `main` is ahead of `origin`; `pinNote` says so.
  Never pin an older commit.
- **Float32 vs float64.** The JS ports run in doubles like the GDScript copy;
  the shader runs float32. The tabs say so where it matters (tab 3's note, the
  float32 gotcha card).
