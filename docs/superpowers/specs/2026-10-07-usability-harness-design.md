# Usability fixes and headless UI test harness — design

**Date:** 2026-10-07
**Scope:** the console window ("Fractacular window"), the noise-field editor
window, and a test suite that drives both the way a player does, headlessly.

## What was found by using the app

The app was driven for real on a Retina MacBook (screen scale 2.0), both the
native build and the deployed web build. Findings, in order of severity:

1. **Everything renders at one logical unit per physical pixel.** The project
   leaves `display/window/dpi/allow_hidpi` on (the default), so on a 2x display
   the 1280x800 main window is 640x400 points, the 1000x700 console is 500x350
   points, and the 1100x700 noise window is 550x350 points. Fonts, dropdown
   arrows, slider grips and scrollbars are half size; the console's whole Shape
   list nearly fits in 350 points so there is almost nothing to scroll, and the
   dropdown buttons are a few points tall. The web build has the same problem
   (the canvas is created at `devicePixelRatio` 2). This is the most likely
   cause of "scroll isn't working, neither are dropdowns": both *do* work when
   hit, but the targets are tiny and the scroll range is near zero.
2. **Resizing the window blacks out the view.** `FractalView._apply_size`
   resizes the SubViewport (which reallocates its texture) but never calls
   `request_frame()`, so with `UPDATE_ONCE` already consumed the new target is
   never drawn until the camera or a parameter changes. Reproduced on the
   native build (drag the corner) and in the web build (browser resize).
3. **The noise editor is empty in the exported (web) build.** `NoiseNodeRegistry`
   scans `res://src/noise/nodes` with `DirAccess`; in a PCK the scripts are
   `.gdc` so nothing matches and every node is "unknown" (bare title, no ports,
   no rows, no preview). The deployed site shows this today.
4. **The console cannot be opened on the web if the Ctrl tap does not
   register.** Ctrl is the only way in; browsers can swallow a bare Control
   tap. The noise editor has a pause-menu button; the console has none.
5. **The console and noise windows open at the top-left of the screen**, not
   over the main window: `_center_in_parent` mixes the parent viewport's
   logical size with native screen coordinates.

Verified working by real input on the native build: the Colour dropdown opens
as a native popup and selecting an item recolours the fractal; the Shape list
scrolls with the wheel; the noise add menu opens on right-click and adds a
Value noise node with a live preview.

## Fixes

### UiScale (`src/ui/ui_scale.gd`)

A small static helper that owns the one fact "how many pixels is a logical
unit":

- `factor() -> float`: `override` when non-zero (tests), else
  `clampf(DisplayServer.screen_get_scale(), 1.0, 4.0)`; headless reports 1.
- `apply(window: Window)`: `content_scale_mode = DISABLED`,
  `content_scale_factor = factor()`. Idempotent.
- `px(logical: Vector2i) -> Vector2i`: `logical * factor()`.
- `fit_main_window(window: Window, logical: Vector2i)`: once per process and
  never on the web, if the main window is still at the project's default pixel
  size, set its size to `px(logical)` so the window keeps its *point* size on a
  HiDPI screen. A window the player has already resized is left alone.

Callers: `MainMenu._ready` and `Main._ready` apply it to the root window (and
fit it to 1280x800); `ConsoleWindow.setup` and `NoiseWindow.setup` apply it to
themselves and size themselves in `px(DEFAULT_SIZE)` / `px(MIN_SIZE)`.

Popups (OptionButton menus, the noise add menu) must come out at the same
scale. Godot propagates `content_scale_factor` from a window to the popups it
spawns; the native acceptance pass confirms it, and if a popup is found at 1x
the window applies `UiScale.apply` to it on `about_to_popup`.

### FractalView renders in physical pixels

`_apply_size` computes the SubViewport size as
`size * render_scale * content scale` (the window's `content_scale_factor`, 1
when there is no window), so the still frame is sharp on a HiDPI screen and the
governor's render scale means the same fraction it did. `project` / `unproject`
keep working in logical units because `size` is logical. Whenever the pixel
size changes `_apply_size` calls `request_frame()` — the resize fix.

### NoiseNodeRegistry holds its scripts

`NODE_SCRIPTS` is a const array of `preload`ed node scripts, one per file in
`src/noise/nodes`. `all()` instantiates those; no `DirAccess`. A test scans the
directory (which works from source) and fails if any `.gd` file there is not in
the list, so dropping in a node still cannot be forgotten silently.

### Console button in the pause menu

`PauseMenu` gains `console_button` ("Console…") next to the noise button and a
`console_requested` signal; `Main` opens the console, frees the mouse and
resumes, mirroring `_open_noise_from_menu`.

### Windows open over the main window

`_center_in_parent` (shared through a `WindowPlacement.center_over(window,
parent_window)` static in `ui_scale.gd`): embedded → centred in the embedder's
visible rect; native → `parent.position + (parent.size - size) / 2` in screen
pixels.

## Headless UI driver (`tests/ui_driver.gd`)

Why it is possible: in headless the root window is 64x64 and sub-windows are
*embedded* in it. Giving the root `content_scale_mode = CANVAS_ITEMS` and
`content_scale_size = 1280x800` makes it a real 1280x800 logical surface where
embedded windows and popups lay out at their true size. Events pushed with
`root.push_input(event, true)` at **global** coordinates (control rect plus the
positions of its embedding windows) go through the same GUI hit-testing a real
click does: this was measured to open an OptionButton's popup, pick an item,
press a button and scroll a ScrollContainer. Pushing into the sub-window
directly does not deliver (the embedder owns dispatch), so the driver always
goes through the root.

`UiDriver` (RefCounted, built by a test with its SceneTree):

| call | what it does |
|---|---|
| `setup()` | scales the root as above |
| `global_center(control)` / `global_point(control, fraction)` | window-aware global coordinates |
| `move_to(control or point)` | mouse motion |
| `click(control, button = LEFT)`, `click_at(point)`, `right_click` | motion, press, frame, release, frame |
| `drag(from, to, steps = 8)` | press, intermediate motions, release |
| `wheel(control, down: bool, times = 1)` | wheel button events at the control |
| `pan(control, delta)` | an `InputEventPanGesture` (macOS trackpad scrolling) |
| `key(physical, pressed)`, `tap(physical)`, `hold(physical, seconds)` | key events through `Input.parse_input_event`, with keycode and unicode filled in |
| `type_text(line_edit, text)` | click, select all, one key event per character, Enter |
| `select_option(option_button, label)` | click to open the popup, move down it until `get_focused_item()` is the item, click |
| `frames(n)` | wait |

Everything a test checks is observable state: table values, shader uniforms
on the view's material, scroll positions, popup visibility, saved JSON.

## Test suites

All headless, run by `tests/run_all.sh`, no desktop control anywhere.

- `tests/ui_scale_test.gd` — `UiScale.factor()` honours the override and clamps;
  `apply` sets the window; `fit_main_window` scales a default-sized window
  once and leaves a resized one alone; `FractalView` pixel size follows the
  window's content scale; a resize requests a frame.
- `tests/noise_registry_test.gd` (extended) — the preloaded list matches the
  directory listing exactly; `type_by_id` works without `DirAccess`.
- `tests/ui_console_test.gd` — the console in a scaled root: wheel over a row
  label, over a slider and over an *unfocused* spin box scrolls the list and
  does not change the value; a pan gesture scrolls; the Colour dropdown opens
  on click and a click on "Blue" sets `color_mode`; a row's Source dropdown
  selects "Axis A" and the binding appears; a slider click moves the value;
  typing into a spin box and pressing Enter writes the table; Add axis, key
  capture and remove work by clicks.
- `tests/ui_noise_test.gd` — the noise window in a scaled root: right-click on
  the canvas opens the add menu and clicking "Value noise" adds a node with a
  preview; `connection_request` from the GraphEdit wires it to Displace and the
  view's shader gains the noise uniforms; a slider click on the node's Scale
  row pushes a new uniform value without a rebuild; the Extent spin box changes
  the preview uniform; the wire menu disconnects; Save…/Load… round-trips
  through `user://`.
- `tests/ui_journey_test.gd` — one player session through `main.tscn`: Play
  from the title menu; Ctrl tap opens the console and frees the mouse; a
  console row sets Scale and the shader sees it; Axis A bound to Fold limit at
  gain 0.5 then E held for a second moves the readout and the uniform; WASD
  and mouse motion move the camera; the pause menu's Console… and Noise
  editor… buttons open their windows; the noise graph gets a wired Value noise;
  Save view… to `user://` then New noise field + reload restores shape,
  bindings, camera and noise; the root is resized and the view requests a
  frame; Back to Menu returns to the title.
- `tests/screenshots.gd` (extended, windowed) — a `console_window.png` and a
  `noise_window.png` of the two windows rendered embedded in the one existing
  window, each required to be non-black. Still launched through `open -g` as
  today and still no desktop control.

## Out of scope

Rewriting the native windows as in-canvas floating windows (Fractacular's
approach), a web-specific Ctrl handler, and any change to the shaders.
