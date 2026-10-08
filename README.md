# Help I'm Stuck In A Fractal

A from-scratch Godot 4.6 Mandelbox viewer that emulates the renderer at
[icefractal.com/mandelbox/](https://icefractal.com/mandelbox/): the same default
view, the four shape sliders, the thirteen colour modes, the precision control,
Julia mode and an orbit camera. On top of the site it adds a distance-scaled
free-fly camera, an adaptive-resolution governor that keeps the frame rate up
while you move, and a runtime controls panel. It is built on the **GL
Compatibility** renderer (WebGL 2) so it is web-exportable.

GDScript only — no C#, even though the Godot build on disk is the Mono build.

## Run

```bash
./run.sh            # run the project
./run.sh --editor   # open it in the Godot editor instead
```

`run.sh` finds `godot4` on your `PATH` (or falls back to `Godot_mono.app` /
`Godot.app`), refreshes Godot's script-class cache when a script has changed,
and then launches the main scene: the **Icebox Nav** title menu (Play Game,
Settings, Quit; Quit is hidden in a web build). Set `GODOT=/path/to/godot` to use a different
binary.

## Controls

Tap **Ctrl** to open the controls panel. Everything the panel does not own is
driven directly by the mouse and keyboard. Press **Escape** to pause: the pause
menu offers Resume, Settings and Back to Menu, and Escape again steps back out.

**Settings** (from the title menu or the pause menu) has two tabs.

- **Controls** holds the mouse sensitivity. It is the player's preference, not
  part of a view: it is kept in `user://settings.cfg`, survives restarts, and
  loading a saved view does not change it.
- **Renderer** tunes how the open view is rendered, and is saved with the view
  (so it is only enabled from the pause menu). While it is showing, the pause
  dim lightens so each change can be seen behind the menu.

| Renderer option | what it does |
|---|---|
| **Detail** | scales the precision everywhere (higher = finer structure, more steps) |
| **Full-detail range** | how far full detail reaches, in multiples of the camera's distance to the nearest surface, so it means the same at any zoom depth |
| **Detail falloff** | how quickly detail coarsens past that range; 0 (the default) keeps detail matched to the pixel at every distance |
| **Max march steps** | the step budget per ray (default 128: 96 coarse + 32 fine) |
| **Min resolution** | the lowest render scale Fast Controls may drop to while moving (default 25%) |
| **Fast Controls** | the same toggle as in the Q panel |

A ray stops once the distance estimate falls below
`precision / detail × t × max(1, t / (range × d₀))^falloff`, where `t` is the
distance along the ray and `d₀` the camera's distance to the nearest surface.

### Load shedding

With Fast Controls on, the render scale is the first thing to give while you
move. Once it is at **Min resolution** and the frame rate is still under 24 fps,
the governor sheds quality a level at a time:

| level | distance fog (× d₀) | detail | step budget | Fly speed |
|---|---|---|---|---|
| 0 | none | 100% | 100% | — |
| 1 | 400 | 75% | 100% | — |
| 2 | 150 | 55% | 75% | — |
| 3 | 60 | 40% | 50% | — |
| 4 | 40 | 35% | 50% | capped at 40% |

Rays stop at the fog distance, and the view fades into a tint of the current
colour mode on the way there. The thresholds are sticky: a shed needs 0.5 s
under 24 fps (and 1 s since the last change), a restore needs 2 s over 40 fps,
nothing changes in between, and a shed soon after a restore doubles the next
restore's wait (up to 16 s). The level is kept while you are still, but the
still frame always renders at full quality. The Q panel shows `load shed N/4`
while a level is active.

### Fly camera (default)

| key / action | what it does |
|---|---|
| **Ctrl** (tap) | toggle the controls panel (also releases/recaptures the mouse); fires on release, so Ctrl+S and Ctrl+P still work |
| **N** | toggle the noise-field editor (also releases/recaptures the mouse) |
| **Escape** | pause menu (releases the mouse; resuming recaptures it) |
| **W / A / S / D** | move forward / left / back / right |
| **Space / Backspace** | move up / down (world-relative to the camera's own up) |
| **Shift** (hold) | sprint — multiply the travel speed by 4 while held |
| mouse move | mouse-look while captured (yaw about world +Z, pitch about the camera's right; no roll) |
| mouse wheel | adjust the speed factor (×1.25 per tick up, ÷1.25 down; clamped 0.01–100) |
| click | with the mouse free, click the view to hide the panel and recapture the mouse |

Movement speed scales with the distance to the nearest surface — roughly one
second covers the gap to whatever you are looking at — so flight stays usable
from far away and slows down automatically as you approach the fractal.

### Orbit camera

Switch to **Orbit** from the panel's Camera dropdown. The mouse is never
captured in this mode.

| action | what it does |
|---|---|
| left-drag | orbit around the centre point |
| **Shift** + left-drag | pan (moves both the camera and the centre) |
| right-drag, or **Alt** + left-drag | dolly in and out |
| mouse wheel | zoom toward the point under the cursor |
| click (no drag) | re-centre on the surface under the cursor (or the origin if nothing is hit nearby) |

### Controls panel (Ctrl)

| row | controls |
|---|---|
| **Save** / **Load** | pick a file in a native panel; saves live in `saves/`, tracked by git (shape, colour, precision, renderer options, Julia, camera). The current file's name sits to the right |
| **Slice (Scale)** | the Mandelbox scale |
| **Inner Radius** / **Fold** / **Outer Radius** | the three remaining shape parameters |
| **Color** | one of the thirteen colour modes (Grayscale, Ice Fractal, Borg, Rainbow, Rainbow 2, Rainbow 3, Rainbow Metal, Blue, Blue 2, Pink-Blue, Ice Box, Ice Box 2, Gold) |
| **Precision** | ray-march precision (smaller = sharper, slower) |
| **Julia** | toggle Julia mode; the X/Y/Z fields set the Julia point, which also has a draggable on-screen marker |
| **Fast Controls** | let the resolution governor drop render scale, then shed quality (see Load shedding), while you interact |
| **Camera** | Fly or Orbit |
| **Mouse sensitivity** | look / orbit speed (the same setting as in Settings) |

**⌘S** (Ctrl+S elsewhere) saves over the current file without a panel; with
no current file it opens the Save panel. The line under the buttons reports
each save and load, including any values a file had that this build skipped.

**⌘P** (Ctrl+P elsewhere) copies a screenshot of the fractal, without the panel
or other UI, to the clipboard as a PNG. On Linux this needs `xclip`.

While Julia mode is on, a white ring marks the Julia point in the view; drag it
(with the mouse free) to move the point in the plane facing the camera.

## Saved views

A save is a small JSON file: a `fractal` section with every panel value
(colour mode by the site's id, camera mode as `"fly"`/`"orbit"`, the Julia
point as `[x, y, z]`) and a `camera` section with the eye, forward and up
vectors and the speed factor. Loading skips anything it does not recognise or
cannot read, with a warning, and leaves values a file does not mention as they
are. An exported build cannot write into the project, so it saves to
`user://saves/` instead.

| file | what it is |
|---|---|
| `saves/default.json` | the opening view |
| `saves/juliaIceField.json` | Julia mode at `(-0.23, 1.512, 1.892)`, Slice −2.29, Inner 0, Fold 0.72, Outer 0.29, Ice Fractal, precision 0.00002 |
| `saves/juliaIceTerraces.json` | Julia mode at `(-0.23, 1.512, 1.892)`, Slice −1.88, Inner 0.49, Fold 0.81, Outer 0.53, Ice Fractal, precision 0.0001 |
| `saves/noiseRidges.json` | the default Ice Fractal view with a noise field wired: value-noise ridges displacing the surface and tinting it blue (see **Noise fields**) |

## Noise fields

Press **N** (or the **Noise editor…** button in the controls panel) to open the
noise-field editor: an in-app node graph, ported from Fractacular's Isolation
window, that builds a 3D scalar field and overlays it on the Mandelbox. Wiring it
to the **Output** node does two things to the picture, live as you edit:

- **Displace** — the field is multiplied by Amplitude and added to the distance
  estimate, so the surface ripples, bulges or erodes. A positive value pushes the
  surface *in*. While Displace is wired, each ray-march step is shortened by the
  Output's **Step scale** so the march does not step over the displaced surface.
- **Tint** — the surface colour is blended toward the Output's **Tint colour** by
  the field, scaled by **Tint strength**.

Opening the editor frees the mouse the way the controls panel does; a click in the view
in Fly mode closes it and recaptures. **Orbit** mode (Camera dropdown) is the
comfortable way to author, since the mouse is never captured. Each node with an
output carries a live preview — a flat slice of the field — and the toolbar's
**Extent** and **Slice Z** choose which slice every preview shows. Right-click the
canvas for the add menu; drag between the coloured ports to wire (green is a
Float scalar field, amber a Vec3 vector field); Delete, Backspace or right-click a
wire to remove it.

| group | nodes |
|---|---|
| **Source** | **Position** — the sample point, in fractal coordinates (one per graph) |
| **Noise** | **Value noise**, **Gradient noise** (both with Octaves/Lacunarity/Gain FBM), **Cellular** (Worley F1) |
| **Vector** | **Transform** (offset, scale, rotate), **Warp** (domain warp), **Combine XYZ**, **Split XYZ** |
| **Math** | **Constant**, **Math** (Add…Fract), **Remap**, **Clamp**, **Mix**, **Length** |
| **Output** | **Output** — Displace and Tint inputs, Amplitude, Step scale, Tint colour and strength (one per graph) |

**Saving.** The graph is saved with the view, as an additive `"noise"` key in the
same JSON file — a view without the key leaves the current field alone. The editor
can also save and load graphs on their own, as `saves/noise/*.json`
(`{"version": 1, "noise": {…}}`), with its own **Save…** / **Load…** buttons.
Load **`saves/noiseRidges.json`** for a one-click demo: value-noise ridges
displacing and blue-tinting the default Ice Fractal view.

A FLOAT parameter edit only re-pushes a shader uniform; an Octaves/op/toggle edit
(baked into the generated GLSL) recompiles the shader. An unwired graph compiles
to nothing, so the picture and its cost are exactly as if there were no editor.

## Default view

The viewer opens on the site's initial framing exactly.

| quantity | value |
|---|---|
| eye | `(8.175847, 3.812460, 3.283393)` |
| looks at | the origin |
| vertical field of view | 40° |
| world up | +Z |

All positions are in **fractal coordinates** — the space the distance estimator
is evaluated in. The site's own camera coordinates are half of ours: a point the
site reports at `(x, y, z)` is `(2x, 2y, 2z)` here.

## Testing

```bash
tests/run_all.sh      # every headless SceneTree test
tests/screenshots.sh  # windowed render check (writes PNGs to screenshots/)
```

`tests/run_all.sh` imports the project (refreshing the class cache) and then runs
each `tests/*_test.gd` headlessly; it exits non-zero if any test fails. Because
the headless renderer produces no pixels, the actual render is verified by
`tests/screenshots.sh`, which launches Godot windowed **without stealing focus**
(via `open -g`), renders the default view and each colour mode, and writes the
results plus a `PASS`/`FAIL` log to `tests/out/screenshots.txt`.

The reference capture from the site lives at
**`docs/reference/icefractal-default.jpg`**. Put `screenshots/default_view.png`
next to it to eyeball the default view against the original — float32 and no
HiDPI mean the pixels differ, but the shape and the blue colour family should
match.

## Systems viz

`docs/viz/` is an in-browser, pannable, zoomable explainer of how the viewer
works: the architecture, one input to one frame, the distance estimator fold
by fold, every dial, the two-phase ray march, the colour modes, the two
normals, the cameras and the resolution governor. Its live figures run
JavaScript ports of the shader and the GDScript (checked at load against the
24 distance-estimator fixtures), and every tooltip links the `file:line` it
describes at a pinned commit.

```bash
./viz.sh                  # open it in your default browser
./viz.sh mandelbox/5      # straight to a tab (1-based)
node tools/viz/check.mjs --print --pane mandelbox   # every cited line exists at the pinned commit
```

It is a dependency-free static page that works from `file://`; the engine is
ported from the sibling project spellfactory. Extend or refresh it with the
`/visualize` skill (`.claude/skills/visualize/`). The links 404 until the
pinned commit is pushed.

## Web export

A single **Web** export preset (threads off) targets the git-ignored
`build/web/`:

```bash
mkdir -p build/web
godot4 --headless --path . --export-release Web build/web/index.html
```

This needs Godot's Web export templates installed; without them the export
reports missing templates rather than writing files.
