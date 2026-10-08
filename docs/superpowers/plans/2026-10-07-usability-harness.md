# Usability fixes and headless UI harness — implementation plan

Spec: `docs/superpowers/specs/2026-10-07-usability-harness-design.md`.
Two independent work streams, each in its own worktree branched from `main`:

- **Stream A — fixes** (branch `ui-fixes`): tasks 1–5.
- **Stream B — harness and UI tests** (branch `ui-tests`): tasks 6–9.

Conventions (from `tests/test_case.gd` and the existing tests): every test is
`tests/<name>_test.gd`, `extends "res://tests/test_case.gd"`, overrides `run()`,
uses `check` / `check_eq` / `check_approx`, and is run by `tests/run_all.sh`
(headless; `godot4 --headless --path . -s tests/<name>_test.gd` for one). No
test may need a window, the desktop, or the network. Write the failing test
first, then the code, then run the test and `tests/run_all.sh`.

## Stream A — fixes

### Task 1 — `UiScale`
- [x] `tests/ui_scale_test.gd`: `factor()` returns `override` when set, else
      clamps `screen_get_scale` into [1, 4] (headless gives 1); `apply(w)` sets
      `content_scale_mode = DISABLED` and `content_scale_factor = factor()`;
      `px(Vector2i(1000, 700))` with override 2 is `(2000, 1400)`;
      `fit_main_window` on a window at the default pixel size doubles it once
      (override 2) and does nothing the second time or when the size differs;
      `center_over` for an embedded window centres in the embedder's rect.
- [x] `src/ui/ui_scale.gd` (`class_name UiScale extends RefCounted`): static
      `override`, `factor()`, `apply()`, `px()`, `fit_main_window()`,
      `center_over(window, parent_window)` per the spec. `fit_main_window`
      returns early on `OS.has_feature("web")`.
- [x] `MainMenu._ready` and `Main._ready`: `UiScale.apply(get_window())` then
      `UiScale.fit_main_window(get_window(), Vector2i(1280, 800))`.
- [x] `ConsoleWindow.setup` / `NoiseWindow.setup`: `UiScale.apply(self)`;
      `size = UiScale.px(DEFAULT_SIZE)`, `min_size = UiScale.px(MIN_SIZE)`;
      replace `_center_in_parent` with `UiScale.center_over(self, parent_window)`.
- [x] Run `tests/console_test.gd`, `tests/noise_window_test.gd`,
      `tests/main_test.gd`, `tests/menus_test.gd`.

### Task 2 — `FractalView` pixel size and the resize fix
- [x] Extend `tests/fractal_view_test.gd`: after `set_render_scale(1.0)` and a
      settled frame, force `UPDATE_DISABLED`, change `size`, and check the
      SubViewport is `UPDATE_ONCE` again; with the view in a Window whose
      `content_scale_factor` is 2, `viewport_size()` is twice the logical size.
- [x] `FractalView._apply_size`: multiply by the window's content scale
      (`get_window().content_scale_factor` if there is a window, else 1);
      call `request_frame()` when the pixel size changed.
- [x] Check `tests/screenshots.gd` and `tests/resolution_governor_test.gd`
      still pass (the screenshot pass runs at scale 1).

### Task 3 — registry without `DirAccess`
- [x] Extend `tests/noise_registry_test.gd`: `NoiseNodeRegistry.NODE_SCRIPTS`
      resource paths equal the sorted `.gd` listing of `src/noise/nodes`
      (DirAccess works from source in the test); `all()` has 18 types.
- [x] `src/noise/noise_node_registry.gd`: `const NODE_SCRIPTS: Array[GDScript] =
      [preload(...), …]`; `all()` iterates it. Update the file comment.
- [x] Run `tests/noise_*_test.gd`.

### Task 4 — pause-menu Console button
- [x] `tests/menus_test.gd`: `console_button` exists, its press emits
      `console_requested`. `tests/main_test.gd`: pressing it from the pause
      menu opens the console, frees the mouse and resumes.
- [x] `PauseMenu`: `console_button` + `console_requested`; `Main`:
      `_open_console_from_menu()` (open, `_free_requested = true`, resume).
- [x] README: mention the button in the Pause menu section.

### Task 5 — stream A wrap-up
- [x] `tests/run_all.sh` green. Commit per task with clear messages.

## Stream B — harness and UI tests

### Task 6 — `tests/ui_driver.gd`
- [x] Implement `UiDriver` per the spec table. `setup()` must set
      `root.content_scale_mode = CANVAS_ITEMS` and `content_scale_size =
      Vector2i(1280, 800)` and wait a frame. Global coordinates: walk up from
      the control through `get_window()`; while the window `is_embedded()`,
      add its `position` and continue from its parent's window.
      All event pushes: `root.push_input(ev, true)`; keys through
      `Input.parse_input_event`.
- [x] `tests/ui_driver_test.gd`: a Button under the root and a Button inside
      an embedded Window both receive `click`; `wheel` scrolls a
      ScrollContainer; `select_option` picks an item of an OptionButton inside
      an embedded Window; `type_text` sets a LineEdit and submits.

### Task 7 — `tests/ui_console_test.gd`
Per the spec list. Build the console exactly as `tests/console_test.gd` does.
Scroll checks must first make the list taller than the window: open it at
`size = Vector2i(1000, 400)` so there is real scroll range.

### Task 8 — `tests/ui_noise_test.gd`
Per the spec list. Build the view and window as `tests/noise_window_test.gd`
does. The add menu: `right_click` on an empty canvas point → `add_menu()` is
visible → `select` "Value noise" by moving down the popup until
`get_focused_item()` matches, then click. Wiring: emit
`graph_edit().connection_request` with the node names (GraphNode `name` is the
node id) and the port indices, then assert `view.shader_uniform_names()` grew.

### Task 9 — `tests/ui_journey_test.gd`
Per the spec list. Start from `res://src/ui/main_menu.tscn` added under the
root, click Play, wait for `main.tscn` (poll `root` children for `Main`).
Save to `user://ui_journey.json`; delete it at the end. The Console… button
step depends on Stream A: write it against `pause_menu().console_button` and
guard with `if pause.get("console_button") != null` so the test passes before
and after the merge; remove the guard once both streams are merged.

### Task 10 — screenshot pass (after merge)
- [x] `tests/screenshots.gd`: `root.gui_embed_subwindows = true`, build a
      `ConsoleWindow` and a `NoiseWindow` (with the view), open them, render
      two frames, capture `root.get_texture().get_image()` cropped to each
      window's rect as `console_window.png` / `noise_window.png`; FAIL if the
      crop is all one colour.

## Merge and acceptance (orchestrator)

1. Merge `ui-fixes`, run `tests/run_all.sh`.
2. Merge `ui-tests`, run `tests/run_all.sh`; fix anything the UI tests found.
3. Task 10, then `tests/screenshots.sh`.
4. Native acceptance pass with real input: window sizes in points, dropdowns,
   scroll, noise add/wire, resize stays rendered.
5. README: Testing section (UI driver, new suites), HiDPI note.
6. Commit; push.

## Stream C — embedding and the fixes the UI tests found (branch `ui-embed`)

See the spec's addendum for why.

- [x] Escape from a focused sub-window: `ConsoleWindow` / `NoiseWindow` emit
      `unhandled_key` for keys they do not use and `Main` dispatches them;
      `pause()` hides open sub-windows (they draw over the pause menu) and
      `resume()` shows them again. `ui_journey_test.gd`: the first Escape
      closes the focused noise window, the second pauses; the Console… step
      runs unguarded.
- [x] T1 Embed: `display/window/subwindows/embed_subwindows=true`; comments
      and README describe windows inside the main window; `main_test.gd`
      clicks through the root (a click on the console stays in it, a click on
      the view recaptures, the console stays open).
- [x] T2 Console layout: a `VSplitContainer`, the Shape inspector on top with
      the full width, the Movement pane below at its natural height;
      `ui_console_test.gd` checks slider width, the pane and every axis widget
      inside the window and ✕ removing an axis at the default size.
- [x] T3 Paused file panels: `WorkspaceFiles` runs `PROCESS_MODE_ALWAYS`; the
      journey types the file name and presses Enter to save and to load.
- [x] T4 The resize `known_bug` is a plain check; `known_bug` and
      `tests/ui_test_case.gd` are gone.
- [x] T5 Docs: this list, the spec addendum, README.
- [x] `tests/run_all.sh` green.
