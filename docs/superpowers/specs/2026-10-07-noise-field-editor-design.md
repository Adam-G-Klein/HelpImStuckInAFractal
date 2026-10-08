# Noise field editor — design

Overlay authored 3D noise fields on the Mandelbox. The field is built as a
node graph in an in-app editor (Godot's runtime `GraphEdit`, ported from
Fractacular's Isolation window), compiled to GLSL, and spliced into the
Mandelbox shader. Two things a field can do to the picture: **displace** the
surface (added to the distance estimate) and **tint** the colour.

Decisions below were made as defaults on 2026-10-07 without a brainstorm, at
the user's request ("make default calls, go straight for implementation").
Each is a call, not a law; change it when the picture says to.

## Goals

- An editor you open from the running viewer, author a 3D scalar field in,
  and see the result on the fractal as you edit.
- Nodes with typed ports, parameters inline, a live preview per node, a
  right-click catalogue, wires validated as you draw them. The same feel as
  Fractacular's Isolation window.
- The graph saved with the view, and also on its own, as JSON.
- Everything but pixels tested headlessly; the pixels in the screenshot pass.
- Unchanged picture and cost when nothing is wired to Output.

## Non-goals

Bindings (Fractacular's X/Y/Z/Time drives) — there is no movement point here.
Multiple graphs or layering. Time-varying fields (no clock uniform, yet; the
codegen should not make one hard). Editing in the Godot editor. Web-export
node discovery (same `DirAccess` scan caveat as Fractacular).

## How a graph becomes pixels

`src/fractal/mandelbox.gdshader` stays a complete, compiling shader. It gains
one marked region holding three stub functions:

```glsl
// NOISE:BEGIN
float noise_displace(vec3 p) { return 0.0; }
float noise_step_scale() { return 1.0; }
vec3 noise_tint(vec3 col, vec3 p) { return col; }
// NOISE:END
```

and three call sites: `de()` and `field()` both add `noise_displace(p)` to
their result (so the high-precision normal and the Ice Fractal normal both
see the displacement), each ray-march step advances by `d * noise_step_scale()`
instead of `d`, and the final colour passes through `noise_tint(col, v)`.

`NoiseCompiler.compile(graph) -> {code: String, uniforms: Dictionary, errors: Array}`
emits GLSL for the region: the noise library functions it needs (value,
gradient and cellular noise, FBM), one `uniform` per numeric node parameter
named `n_<node_id>_<param>`, and the three functions with bodies that evaluate
the graph in topological order (`float v_<node_id>_<port>` locals). When
nothing is wired to an Output port, that function is the stub above, so an
unwired graph costs nothing.

`FractalView.set_noise_graph(graph)` listens to the graph. A structural change
(`changed`), or an ENUM/INT/BOOL parameter edit (these are baked into the code:
loop bounds and op switches, no runtime branching), rebuilds the shader: a new
`Shader` with the region replaced, swapped into the material, every uniform
re-pushed (params, camera, noise). A FLOAT edit only pushes its uniform. If the
new shader fails to compile (empty uniform list), the old shader stays and the
failure is reported to the panel's status line and the console.

### Port types

Two, frozen and ordered (append only): `FLOAT` a scalar field, `VEC3` a vector
field. An unwired FLOAT input reads the port's own default constant; an unwired
VEC3 input reads `p`, the sample position.

### Node catalogue (`src/noise/nodes/*.gd`, scanned like Fractacular's)

Each node is a `NoiseNodeType` subclass: ports, params, and a
`emit(inputs: Array[String], params, out_var) -> String` (or equivalent) that
returns the GLSL statements for its outputs. Groups and order as the add menu
lists them.

| group | node | in → out | what it does |
|---|---|---|---|
| Source | **Position** | → P (VEC3) | the sample position in fractal coordinates. Fixed, one per graph, like Fractacular's Source. |
| Noise | **Value noise** | P → Float | 3D value noise with quintic interpolation; FBM via Octaves, Lacunarity, Gain; Scale, Seed. Output in [-1, 1]. |
| Noise | **Gradient noise** | P → Float | 3D Perlin-style gradient noise, same FBM params. |
| Noise | **Cellular** | P → Float | Worley F1 distance, Scale, Seed, Jitter. |
| Vector | **Transform** | P → P | Offset (x, y, z), uniform Scale, rotation about an axis (Axis enum, Angle). |
| Vector | **Warp** | P, D (VEC3) → P | `P + Amount * D`: domain warp. |
| Vector | **Combine XYZ** | X, Y, Z (Float) → VEC3 | |
| Vector | **Split XYZ** | V (VEC3) → X, Y, Z | |
| Math | **Constant** | → Float | Value. |
| Math | **Math** | A, B → Float | Op enum: Add, Subtract, Multiply, Divide, Min, Max, Power, Abs(A), Sin(A), Cos(A), Floor(A), Fract(A). |
| Math | **Remap** | A → Float | from [In min, In max] to [Out min, Out max], optional Clamp. |
| Math | **Clamp** | A → Float | Min, Max. |
| Math | **Mix** | A, B, T → Float | `mix(A, B, T)`. |
| Math | **Length** | V (VEC3) → Float | `length(V)`. |
| Output | **Output** | Displace (Float), Tint (Float) → | Fixed, one per graph. Amplitude (the Displace field is multiplied by it before it is added to the distance), Step scale (0.1–1, the march step multiplier while Displace is wired; 1 when not), Tint colour (an extra, colour picker), Tint strength. |

Tint: `col = mix(col, tint_colour, clamp(tint, 0, 1) * strength)`.

Displacement sign: positive pushes the surface **in** (it adds to the
distance). The docstrings say so.

### Previews

Each node with a FLOAT or VEC3 output gets a live preview: a `ColorRect`
carrying a `ShaderMaterial` whose shader is
`NoiseCompiler.compile_preview(graph, node_id, port)`: a canvas_item shader
that samples the subgraph up to that port over an XY slice of fractal space
(`p = vec3((UV - 0.5) * 2 * extent, slice_z)`), greyscale for a FLOAT
(`v * 0.5 + 0.5`), `abs(V) / extent` as RGB for a VEC3. No SubViewport: the
shader draws straight into the GraphNode. The editor has a toolbar row with
the preview Extent (default 4) and Slice Z (default 0) that every preview
shares. Previews rebuild on the same triggers as the main shader, and share
the uniform naming so a FLOAT edit pushes to every preview material too.

## The editor

`NoiseEditor` (src/ui/noise_editor.gd) is a port of Fractacular's
`IsolationEditor`: a GraphEdit, one GraphNode per graph node with typed slots
(slot colours per port type), a compact parameter row per param, a preview,
collapse toggles for rows and preview (persisted), a right-click add menu
grouped by `group` with the description as tooltip, Delete/Backspace on a
highlighted wire or selected nodes, `add_node_requested` emitted rather than
adding itself, and every connection going through `NoiseGraph.can_connect`.

Parameter rows: a port of `AttributeRow`'s compact form with the binding
widgets removed — label, slider, spin box for FLOAT/INT; OptionButton for
ENUM; CheckBox for BOOL. `NoiseParamSpec` and `NoiseParamTable` are
`AttributeSpec` / `AttributeTable` with Category and bindings removed.

Toolbar above the GraphEdit: **New** (back to the default graph), **Load…**
and **Save…** (graph-only JSON in `saves/noise/`, native dialogs, same
`WorkspaceFiles` pattern — a second instance pointed at that directory and
filter), the preview Extent and Slice Z spin boxes, and a status label.

Hosting: an embedded `Window` (title "Noise field", resizable, close hides,
default 1100×700, centred) owned by Main. Opened and closed by the **N** key
(`toggle_noise_editor` input action) and by a **Noise editor…** button in the
controls panel. Opening frees the mouse the way the Q panel does; a click in
the view while in Fly mode hides the editor and the panel and recaptures.
Orbit mode is the comfortable way to author: the mouse is never captured.

## Model

`NoiseGraph` (src/noise/noise_graph.gd) is a port of `IsolationGraph`: nodes
with id, type, position, params table, extras, two collapse flags; links;
`can_connect` (range, type, one link per input, no cycles); `order()`;
`to_dict` / `from_dict` with warnings; `resolve_type` injected. `position_id()`
and `output_id()` replace `source_id()` and `output_id()`. Default graph:
Position and Output, nothing wired.

## Saving

A view save gains an additive `"noise"` key holding the graph dict.
`Workspace.VERSION` stays 1. A file without the key leaves the current graph
alone, by the existing rule. A graph file on its own is `{"version": 1,
"noise": {...}}`.

Ship `saves/noiseRidges.json`: a view with a wired graph that looks good
(choose it from a screenshot run), so there is a one-click demo.

## Tests

Headless: the graph model (port of `isolation_graph_test`), the registry and
every type's schema (ports, tooltips, params; port of the schema checks), the
compiler (every node type alone and the default graph compile into a shader
with a non-empty uniform list; stubs when unwired; uniform naming; ENUM edits
recompile and FLOAT edits do not), the editor (port of `isolation_editor_test`
with previews as ColorRects), the view (swapping the shader keeps every base
uniform and adds the graph's), the workspace round trip with the noise key,
Main (N opens the window and frees the mouse; a click in Fly mode closes it).
Windowed: `tests/screenshots.gd` renders `saves/noiseRidges.json` to
`screenshots/noise_ridges.png` and checks it differs from the default view
and is not blank; it launches through `open -g` as today.

`tests/shader_test.gd` keeps passing: the base file's uniform list is
unchanged because the Output node's uniforms live in the generated region.

## Files

```
src/noise/
  noise_port.gd            FLOAT / VEC3: names, colours, tooltips, defaults
  noise_param_spec.gd      AttributeSpec minus Category and bindings
  noise_param_table.gd     AttributeTable minus bindings
  noise_node_type.gd       ports, params, extras, emit()
  noise_node_registry.gd   scans src/noise/nodes
  noise_graph.gd           the model
  noise_compiler.gd        graph -> GLSL region, preview shaders
  noise_library.gdshaderinc   the noise functions the compiler pastes in
  nodes/*.gd               the catalogue
src/ui/
  noise_editor.gd          GraphEdit over one NoiseGraph
  noise_param_row.gd       compact row
  noise_window.gd          the embedded Window hosting the editor + toolbar
src/fractal/fractal_view.gd    set_noise_graph, rebuild, push
src/fractal/mandelbox.gdshader the NOISE region and call sites
src/main.gd                    owns the window, N key, mouse rule
src/ui/controls_panel.gd       the button
src/workspace/workspace.gd     the "noise" key
tests/*                        as above
README.md                      a Noise fields section and the N key
```
