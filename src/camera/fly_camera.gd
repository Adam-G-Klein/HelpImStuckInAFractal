class_name FlyCamera
extends Node
## Free-fly camera: mouse-look (yaw about world +Z, pitch about the camera's own
## right, no roll) and WASD/Space/Shift movement whose speed scales with the
## distance to the nearest surface. Reads and writes a shared CameraState.

const WORLD_UP := Vector3(0, 0, 1)
const MAX_FORWARD_Z := 0.9998476951563913   # sin(89 deg): keep forward 1 deg off +/-Z

var enabled := false

var _params: FractalParams
var _camera: CameraState


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera


## Mouse dispatch is owned by Main, which calls this for the active camera.
## Returns true when the event was consumed. Look only while captured; wheel
## adjusts the speed factor.
func handle_event(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative.x, event.relative.y)
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll(true)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll(false)
			return true
	return false


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var dir := move_direction()
	if dir.length() == 0.0:
		return
	var t := _camera.transform
	t.origin += dir * current_speed() * delta
	_camera.transform = t


## Rotate the view by a mouse delta (pixels). Yaw turns the heading about world
## +Z (pitch preserved); pitch sets the elevation angle, clamped to +/-89 deg so
## the forward vector never reaches +/-Z. Clamping the ANGLE (not forward.z after
## an arbitrary rotation) means even a huge delta saturates instead of wrapping.
func apply_look(dx: float, dy: float) -> void:
	var sens := _params.mouse_sensitivity
	var fwd := _camera.forward().rotated(WORLD_UP, deg_to_rad(-dx * sens))  # yaw keeps pitch
	var max_pitch := asin(MAX_FORWARD_Z)
	var pitch_new := clampf(asin(clampf(fwd.z, -1.0, 1.0)) + deg_to_rad(-dy * sens), -max_pitch, max_pitch)
	var horiz := Vector3(fwd.x, fwd.y, 0.0)
	if horiz.length() > 1e-9:
		horiz = horiz.normalized()
	else:
		horiz = Vector3(_camera.right().y, -_camera.right().x, 0.0).normalized()
	_set_forward(horiz * cos(pitch_new) + WORLD_UP * sin(pitch_new))


## Unit movement direction in world space from the six actions (camera axes).
func move_direction() -> Vector3:
	var f := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var s := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var u := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	var dir := _camera.forward() * f + _camera.right() * s + _camera.up() * u
	if dir.length() > 0.0:
		dir = dir.normalized()
	return dir


## Travel speed: ~one second covers the distance to the nearest surface.
func current_speed() -> float:
	var d := DistanceEstimator.estimate(_camera.eye(), _params)
	return clampf(d, 1e-6, 20.0) * _camera.speed_factor


func scroll(up: bool) -> void:
	var f := _camera.speed_factor * (1.25 if up else 1.0 / 1.25)
	_camera.speed_factor = clampf(f, 0.01, 100.0)


## Rebuild the basis from a forward vector with +Z as the up hint (no roll),
## keeping the eye where it is.
func _set_forward(fwd: Vector3) -> void:
	var t := Transform3D(Basis.IDENTITY, _camera.eye())
	_camera.transform = t.looking_at(_camera.eye() + fwd, WORLD_UP)
