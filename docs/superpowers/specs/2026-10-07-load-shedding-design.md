# Load shedding and the idle fix — design

Date: 2026-10-07

## Problems

1. **The view is choppy while sitting still.** With the mouse captured in Fly
   mode, macOS delivers stray zero-delta mouse-motion events. Each one runs
   `FlyCamera.apply_look`, which rebuilds the transform and assigns it, and
   `CameraState`'s setter emits `changed` even when nothing changed. The
   governor then renders low-scale frames followed by one full-scale final
   frame, over and over: a still view that keeps flipping resolution and paying
   for full-resolution frames. A profile of the stock build saw 17 such no-op
   camera changes in a few seconds with nobody touching the input.
2. **There is only one lever.** When the render scale is already at
   `min_render_scale` and the frame rate is still low, nothing else gives.

## Idle fix

- `CameraState` setters emit `changed` only when the value differs (exact
  comparison, so deep-zoom moves of 1e-7 are never swallowed).
- `FlyCamera` ignores mouse motion whose relative is zero, and `apply_look(0, 0)`
  is a no-op.
- `ResolutionGovernor` waits for `settle` (0.15 s) of quiet before the
  full-scale final frame. Until then it is in a new `SETTLING` mode that renders
  nothing (the last low-scale frame stays on screen). A change during settling
  goes straight back to `CONTINUOUS`, so stray input can no longer buy a string
  of full-resolution frames.
- The governor only touches the view's scale and update mode when they change.

## Load-shed ladder

`src/perf/load_shedder.gd` — `LoadShedder`, a `RefCounted` with a pure
`step(frame_time, ema, can_shed)` like the governor's, owned by the governor.

| Level | Fog distance (× near) | Detail × | Step budget × | Fly speed × |
|---|---|---|---|---|
| 0 | off | 1.00 | 1.00 | 1.0 |
| 1 | 400 | 0.75 | 1.00 | 1.0 |
| 2 | 150 | 0.55 | 0.75 | 1.0 |
| 3 | 60 | 0.40 | 0.50 | 1.0 |
| 4 | 40 | 0.35 | 0.50 | 0.4 |

"near" is the camera's distance to the nearest surface, the same unit the
level-of-detail range uses, so the fog means the same thing at every zoom depth.
The step budget never drops below `FractalParams.MAX_STEPS_MIN`.

### Thresholds (sticky)

- **Order:** the render scale is the first lever. The shedder may only shed
  when the scale is already at the floor (`can_shed`). Levels come off before
  the scale climbs again: the governor raises the scale only at level 0.
- **Shed** one level when the smoothed frame rate stays below 24 fps for 0.5 s,
  and not within 1 s of the last level change.
- **Restore** one level when it stays above 40 fps for the restore dwell
  (2 s to start). Between 24 and 40 fps both timers reset: a dead band.
- **Anti-flap:** a shed within 5 s of a restore doubles the restore dwell (up to
  16 s). A restore that sticks for 10 s (no shed since) resets it to 2 s. A
  plain "10 s on one level" rule would fire while the shedder is still waiting
  out a long restore dwell and undo the backoff.
- **Idle:** the level and the moving render scale persist while idle, so
  moving again resumes where it left off rather than at full scale. The final still frame always renders at level 0 (no fog, full
  detail and budget).
- **Fast Controls off:** level 0, no shedding (as the scale stays 1.0 today).

## Fog

Shader uniforms `fog_dist` (× `near_dist`, 0 = off) and `fog_color`.

- Rays stop at `fog_dist × near_dist` as well as at the cube's exit. That cut
  is where the time is saved.
- Every ray is mixed toward `fog_color` by
  `smoothstep(0.35 × t_fog, t_fog, distance)`, and a miss counts as infinitely
  far. While fog is on, the sky becomes the fog colour and far surfaces fade
  into it, with no seam between them.
- `fog_color` is a per-colour-mode tint (`FractalParams.fog_color()`): a dark
  version of each palette, and a light one for the two white-background modes.

## Speed cap

Only the top level caps Fly speed: `FlyCamera.speed_limit` multiplies
`current_speed()`. Main sets it from the governor's `shed_level_changed`
signal. Orbit mode is unaffected.

## Display

The controls panel shows `load shed N/4` while the level is above 0.

## Tests (headless)

- `load_shedder_test.gd`: dwell before shedding, cooldown between sheds, no
  shedding while scale is above the floor, the dead band, restore dwell, and
  the anti-flap backoff.
- `resolution_governor_test.gd`: settling before the final frame, a change
  during settling skipping the final frame, the scale held while level > 0,
  and the level kept through idle but not applied to the final frame.
- `camera_state_test.gd` / `fly_camera_test.gd`: no-op assignments and zero
  looks don't emit; the speed limit scales `current_speed()`.
- `fractal_view_test.gd` / `shader_test.gd`: the shed level pushes the fog,
  detail and step uniforms, and level 0 pushes the original values.

Checking how the fog looks needs a rendered frame, which is a windowed run and
so needs the user's go-ahead first.
