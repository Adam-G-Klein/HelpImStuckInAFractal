class_name FractalParams
extends Resource
## Every value the renderer, cameras and governor read. The shape fields are now
## the RESOLVED knob values, named by catalogue id and written once per frame by
## apply_resolved(); the preference fields (fast_controls, camera_mode,
## mouse_sensitivity) are still edited directly. Setters emit Resource's built-in
## `changed`; apply_resolved batches a frame's writes into at most one emit.

enum CameraMode { FLY, ORBIT }

## Colour-mode ids in the dropdown's order (ids match the site).
const COLOR_MODE_IDS: Array[int] = [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14]
const COLOR_MODE_NAMES: Array[String] = [
	"Grayscale", "Ice Fractal", "Borg", "Rainbow", "Rainbow 2", "Rainbow 3",
	"Rainbow Metal", "Blue", "Blue 2", "Pink-Blue", "Ice Box", "Ice Box 2", "Gold",
]

## The resolved shape fields, in catalogue order. apply_resolved writes these.
const RESOLVED_KEYS: Array[StringName] = [
	&"box_scale", &"fold_limit", &"min_radius", &"fixed_radius", &"fold_order", &"w",
	&"julia_all", &"julia_0", &"julia_1", &"julia_2", &"julia_3",
	&"c_0", &"c_1", &"c_2", &"c_3",
	&"iter_rot_xy", &"iter_rot_xz", &"iter_rot_xw", &"iter_rot_yz", &"iter_rot_yw", &"iter_rot_zw",
	&"color_mode", &"precision",
]

# While true the shape setters do not emit; apply_resolved emits once at the end.
var _suppress := false

# --- Box ---
@export var box_scale: float = -2.09:
	set(v): box_scale = v; _emit()
@export var fold_limit: float = 1.0:
	set(v): fold_limit = v; _emit()
@export var min_radius: float = 0.7:
	set(v): min_radius = v; _emit()
@export var fixed_radius: float = 1.0:
	set(v): fixed_radius = v; _emit()
@export var fold_order: int = 0:
	set(v): fold_order = v; _emit()
@export var w: float = 0.0:
	set(v): w = v; _emit()

# --- Julia ---
@export var julia_all: bool = false:
	set(v): julia_all = v; _emit()
@export var julia_0: bool = false:
	set(v): julia_0 = v; _emit()
@export var julia_1: bool = false:
	set(v): julia_1 = v; _emit()
@export var julia_2: bool = false:
	set(v): julia_2 = v; _emit()
@export var julia_3: bool = false:
	set(v): julia_3 = v; _emit()
@export var c_0: float = -0.23:
	set(v): c_0 = v; _emit()
@export var c_1: float = 1.512:
	set(v): c_1 = v; _emit()
@export var c_2: float = 1.892:
	set(v): c_2 = v; _emit()
@export var c_3: float = 0.0:
	set(v): c_3 = v; _emit()

# --- Iteration rotation (degrees) ---
@export var iter_rot_xy: float = 0.0:
	set(v): iter_rot_xy = v; _emit()
@export var iter_rot_xz: float = 0.0:
	set(v): iter_rot_xz = v; _emit()
@export var iter_rot_xw: float = 0.0:
	set(v): iter_rot_xw = v; _emit()
@export var iter_rot_yz: float = 0.0:
	set(v): iter_rot_yz = v; _emit()
@export var iter_rot_yw: float = 0.0:
	set(v): iter_rot_yw = v; _emit()
@export var iter_rot_zw: float = 0.0:
	set(v): iter_rot_zw = v; _emit()

# --- Render ---
@export var color_mode: int = 1:
	set(v): color_mode = v; _emit()
@export var precision: float = 0.000025:
	set(v): precision = v; _emit()

# --- preferences (edited directly, not resolved) ---
@export var fast_controls: bool = true:
	set(v): fast_controls = v; emit_changed()
@export var camera_mode: CameraMode = CameraMode.FLY:
	set(v): camera_mode = v; emit_changed()
@export var mouse_sensitivity: float = 0.1:
	set(v): mouse_sensitivity = v; emit_changed()


func _emit() -> void:
	if not _suppress:
		emit_changed()


## Write every listed resolved value (by catalogue id) in one batch, emitting
## `changed` at most once and only if something actually differed. A view with
## no active binding costs no signal per frame.
func apply_resolved(values: Dictionary) -> void:
	var dirty := false
	_suppress = true
	for k in RESOLVED_KEYS:
		if not values.has(k):
			continue
		var v: Variant = values[k]
		if get(k) != v:
			set(k, v)
			dirty = true
	_suppress = false
	if dirty:
		emit_changed()


## The Julia constant's first three components, for the marker and orbit camera.
func julia_point() -> Vector3:
	return Vector3(c_0, c_1, c_2)


## Whether the master Julia toggle is on (drives the on-screen marker).
func julia_enabled() -> bool:
	return julia_all
