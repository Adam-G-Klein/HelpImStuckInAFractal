class_name CameraState
extends Resource
## The camera as a Transform3D (Godot convention: forward = -basis.z) plus a
## distance-speed multiplier. Setters emit Resource's built-in `changed`, but
## only when the value actually differs: stray input that re-assigns the same
## transform must not make the governor re-render a still view. The comparison
## is exact, so even a deep-zoom move of 1e-7 counts.

const DEFAULT_EYE := Vector3(8.175847, 3.812460, 3.283393)

@export var transform: Transform3D = Transform3D.IDENTITY:
	set(v):
		if v == transform:
			return
		transform = v
		emit_changed()
@export var speed_factor: float = 1.0:
	set(v):
		if v == speed_factor:
			return
		speed_factor = v
		emit_changed()


func eye() -> Vector3:
	return transform.origin


func forward() -> Vector3:
	return -transform.basis.z


func right() -> Vector3:
	return transform.basis.x


func up() -> Vector3:
	return transform.basis.y


## The site's initial view: eye at DEFAULT_EYE, looking at the origin, +Z up.
static func make_default() -> CameraState:
	var c := CameraState.new()
	var t := Transform3D(Basis.IDENTITY, DEFAULT_EYE)
	c.transform = t.looking_at(Vector3.ZERO, Vector3(0, 0, 1))
	return c
