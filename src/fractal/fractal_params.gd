class_name FractalParams
extends Resource
## Every shape / colour / precision / Julia / camera value for the viewer.
## Setters emit Resource's built-in `changed` signal. Defaults match the site.

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
