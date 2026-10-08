class_name JuliaMarker
extends Control
## Draws a small ring at the projected Julia point and lets the user drag it (in
## the plane facing the camera) while the mouse is free.

const RING_RADIUS := 10.0

var _params: FractalParams
var _camera: CameraState
var _view: FractalView
## The shape table: a drag writes c_0..2 here (through set_default) so the move
## survives the next resolve. May be null for a standalone marker.
var _table: AttributeTable
var _dragging := false
var _drag_depth := 0.0


func setup(params: FractalParams, camera: CameraState, view: FractalView, table: AttributeTable = null) -> void:
	_params = params
	_camera = camera
	_view = view
	_table = table
	params.changed.connect(_on_changed)
	camera.changed.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_on_changed()


func _on_changed() -> void:
	visible = _params.julia_enabled()
	queue_redraw()


## The window pixel of the Julia point, or null when behind the camera.
func screen_point() -> Variant:
	return _view.project(_params.julia_point())


## Start a drag if `mouse` is on the ring and Julia is on. Captures the point's
## camera-space depth so it slides in the facing plane.
func begin_drag(mouse: Vector2) -> bool:
	if not _params.julia_enabled():
		return false
	var sp: Variant = screen_point()
	if sp == null or (sp as Vector2).distance_to(mouse) > RING_RADIUS * 2.0:
		return false
	var rel := _params.julia_point() - _camera.eye()
	_drag_depth = rel.dot(_camera.forward())
	_dragging = true
	return true


func update_drag(mouse: Vector2) -> void:
	if not _dragging:
		return
	var p := _view.unproject(mouse, _drag_depth)
	# The table is canonical (Main resolves it into params each frame); write the
	# move there. Mirror it into params now so the picture follows this frame,
	# even with no resolve loop running (a standalone marker).
	if _table != null:
		_table.set_default(&"c_0", p.x)
		_table.set_default(&"c_1", p.y)
		_table.set_default(&"c_2", p.z)
		_params.apply_resolved({
			&"c_0": _table.get_default(&"c_0"),
			&"c_1": _table.get_default(&"c_1"),
			&"c_2": _table.get_default(&"c_2"),
		})
	else:
		_params.apply_resolved({&"c_0": p.x, &"c_1": p.y, &"c_2": p.z})


func end_drag() -> void:
	_dragging = false


func is_dragging() -> bool:
	return _dragging


func _draw() -> void:
	if not _params.julia_enabled():
		return
	var sp: Variant = screen_point()
	if sp != null:
		draw_arc(sp, RING_RADIUS, 0.0, TAU, 32, Color.WHITE, 2.0, true)
