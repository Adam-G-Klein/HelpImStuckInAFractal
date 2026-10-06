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
and then launches the main scene. Set `GODOT=/path/to/godot` to use a different
binary.

## Controls

Press **Q** to open the controls panel. Everything the panel does not own is
driven directly by the mouse and keyboard.

### Fly camera (default)

| key / action | what it does |
|---|---|
| **Q** | toggle the controls panel (also releases/recaptures the mouse) |
| **W / A / S / D** | move forward / left / back / right |
| **Space / Shift** | move up / down (world-relative to the camera's own up) |
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

### Controls panel (Q)

| row | controls |
|---|---|
| **Save** / **Load** | pick a file in a native panel; saves live in `saves/`, tracked by git (shape, colour, precision, Julia, camera). The current file's name sits to the right |
| **Slice (Scale)** | the Mandelbox scale |
| **Inner Radius** / **Fold** / **Outer Radius** | the three remaining shape parameters |
| **Color** | one of the thirteen colour modes (Grayscale, Ice Fractal, Borg, Rainbow, Rainbow 2, Rainbow 3, Rainbow Metal, Blue, Blue 2, Pink-Blue, Ice Box, Ice Box 2, Gold) |
| **Precision** | ray-march precision (smaller = sharper, slower) |
| **Julia** | toggle Julia mode; the X/Y/Z fields set the Julia point, which also has a draggable on-screen marker |
| **Fast Controls** | let the resolution governor drop render scale while you interact |
| **Camera** | Fly or Orbit |
| **Mouse sensitivity** | look / orbit speed |

**⌘S** (Ctrl+S elsewhere) saves over the current file without a panel; with
no current file it opens the Save panel. The line under the buttons reports
each save and load, including any values a file had that this build skipped.

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

## Web export

A single **Web** export preset (threads off) targets the git-ignored
`build/web/`:

```bash
mkdir -p build/web
godot4 --headless --path . --export-release Web build/web/index.html
```

This needs Godot's Web export templates installed; without them the export
reports missing templates rather than writing files.
