class_name FractalParams
extends Resource
## Every shape / colour / precision / level-of-detail / Julia / camera value for
## the viewer. Setters emit Resource's built-in `changed` signal. Defaults match
## the site (the level-of-detail defaults reproduce its plain pixel cone).

enum CameraMode { FLY, ORBIT }

## Colour-mode ids in the dropdown's order (ids match the site).
const COLOR_MODE_IDS: Array[int] = [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14]
const COLOR_MODE_NAMES: Array[String] = [
	"Grayscale", "Ice Fractal", "Borg", "Rainbow", "Rainbow 2", "Rainbow 3",
	"Rainbow Metal", "Blue", "Blue 2", "Pink-Blue", "Ice Box", "Ice Box 2", "Gold",
]

@export var scale: float = -2.09:
	set(v): scale = v; emit_changed()
@export var inner_radius: float = 0.7:
	set(v): inner_radius = v; emit_changed()
@export var fold_limit: float = 1.0:
	set(v): fold_limit = v; emit_changed()
@export var outer_radius: float = 1.0:
	set(v): outer_radius = v; emit_changed()
@export var color_mode: int = 1:
	set(v): color_mode = v; emit_changed()
@export var precision: float = 0.000025:
	set(v): precision = v; emit_changed()
@export var julia_enabled: bool = false:
	set(v): julia_enabled = v; emit_changed()
@export var julia_point: Vector3 = Vector3(-0.23, 1.512, 1.892):
	set(v): julia_point = v; emit_changed()
@export var fast_controls: bool = true:
	set(v): fast_controls = v; emit_changed()
@export var camera_mode: CameraMode = CameraMode.FLY:
	set(v): camera_mode = v; emit_changed()
@export var mouse_sensitivity: float = 0.1:
	set(v): mouse_sensitivity = v; emit_changed()

## Level of detail with distance. A ray stops once the distance estimate falls
## below hit_epsilon(t, near): the pixel cone `precision × t`, divided by
## `detail`, and coarsened by (t / start)^detail_falloff past start =
## detail_range × the camera's distance to the nearest surface. Measuring the
## range in that distance keeps it meaningful at any zoom depth; a falloff of 0
## is the plain cone. The shader's hit_eps() is the same formula.
const DETAIL_MIN := 0.1
const DETAIL_MAX := 10.0
const DETAIL_RANGE_MIN := 1.0
const DETAIL_RANGE_MAX := 1000.0
const DETAIL_FALLOFF_MAX := 3.0
const NEAR_FLOOR := 1e-6   # the near distance never reaches 0 (a camera on the surface)

## Per colour-mode id, in the dropdown's order.
const FOG_COLORS := {
	0: Vector3(0.22, 0.22, 0.22),    # Grayscale
	1: Vector3(0.14, 0.22, 0.36),    # Ice Fractal
	2: Vector3(0.10, 0.17, 0.10),    # Borg
	3: Vector3(0.24, 0.14, 0.30),    # Rainbow
	4: Vector3(0.20, 0.10, 0.24),    # Rainbow 2
	8: Vector3(0.14, 0.18, 0.30),    # Rainbow 3
	15: Vector3(0.20, 0.20, 0.27),   # Rainbow Metal
	5: Vector3(0.82, 0.88, 1.00),    # Blue (white background)
	6: Vector3(0.85, 0.90, 1.00),    # Blue 2 (white background)
	7: Vector3(0.30, 0.14, 0.27),    # Pink-Blue
	16: Vector3(0.12, 0.26, 0.34),   # Ice Box
	9: Vector3(0.12, 0.26, 0.34),    # Ice Box 2
	14: Vector3(0.28, 0.20, 0.06),   # Gold
}

## The resolution governor never drops below min_render_scale while moving.
const RENDER_SCALE_FLOOR := 0.1

## The march's step budget: three quarters coarse (N=16) and the rest fine
## (N=32), so the default 128 is the original 96 + 32. The shader's loops are
## bounded for MAX_STEPS_MAX.
const MAX_STEPS_MIN := 32
const MAX_STEPS_MAX := 512

@export var detail: float = 1.0:
	set(v): detail = clampf(v, DETAIL_MIN, DETAIL_MAX); emit_changed()
@export var detail_range: float = 10.0:
	set(v): detail_range = clampf(v, DETAIL_RANGE_MIN, DETAIL_RANGE_MAX); emit_changed()
@export var detail_falloff: float = 0.0:
	set(v): detail_falloff = clampf(v, 0.0, DETAIL_FALLOFF_MAX); emit_changed()
@export var min_render_scale: float = 0.25:
	set(v): min_render_scale = clampf(v, RENDER_SCALE_FLOOR, 1.0); emit_changed()
@export var max_steps: int = 128:
	set(v): max_steps = clampi(v, MAX_STEPS_MIN, MAX_STEPS_MAX); emit_changed()


## The hit threshold at ray distance `t`, for a camera `near` from the nearest
## surface. Mirrors hit_eps() in mandelbox.gdshader.
func hit_epsilon(t: float, near: float) -> float:
	var eps := precision / detail * t
	if detail_falloff > 0.0:
		var start := detail_range * maxf(near, NEAR_FLOOR)
		if t > start:
			eps *= pow(t / start, detail_falloff)
	return eps


## The coarse share of a step budget: `budget`, or max_steps when it is 0 (the
## load shedder passes a smaller budget).
func coarse_steps(budget := 0) -> int:
	return (budget if budget > 0 else max_steps) * 3 / 4


func fine_steps(budget := 0) -> int:
	var b := budget if budget > 0 else max_steps
	return b - coarse_steps(b)


## The load shedder's fog tint for the current colour mode: a dark version of
## each palette, and a light one for the two modes drawn on white.
func fog_color() -> Vector3:
	return FOG_COLORS.get(color_mode, Vector3(0.2, 0.2, 0.2))
