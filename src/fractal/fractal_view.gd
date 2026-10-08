class_name FractalView
extends Control
## Renders the fractal in a SubViewport and displays it full-window. Also owns
## the ray maths (project/unproject) so the Julia marker and orbit camera agree
## with the shader exactly.

const TAN_HALF_FOV := 0.36397023426620234  # tan(20 degrees), half of a 40 deg vertical FOV

var render_scale := 1.0
var continuous := false

var _params: FractalParams
var _camera: CameraState
var _viewport: SubViewport
var _rect: ColorRect
var _display: TextureRect
var _material: ShaderMaterial
var _pending_size := Vector2i(1280, 800)


func _ready() -> void:
	_viewport = $SubViewport
	_rect = $SubViewport/ColorRect
	_display = $Display
	_material = _rect.material as ShaderMaterial
	_display.texture = _viewport.get_texture()
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	# The view covers the window, so if it took mouse events the GUI would eat
	# every click and every captured mouse-look motion before Main saw them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_size)
	_apply_size()
	# setup() may have run before _ready wired the material (e.g. a test or the
	# screenshot pass that adds the view and calls setup() in the same frame).
	# Push whatever state is already held so the first frame is not blank.
	if _params != null:
		_push_params()
	if _camera != null:
		_push_camera()
	request_frame()


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera
	if not params.changed.is_connected(_on_params_changed):
		params.changed.connect(_on_params_changed)
	if not camera.changed.is_connected(_on_camera_changed):
		camera.changed.connect(_on_camera_changed)
	_push_params()
	_push_camera()
	request_frame()


func shader_uniform_names() -> Array:
	var out: Array = []
	if _material and _material.shader:
		for u in _material.shader.get_shader_uniform_list():
			out.append(u["name"])
	return out


func viewport_size() -> Vector2i:
	if _viewport == null:
		return Vector2i.ZERO
	return _viewport.size


func set_render_scale(s: float) -> void:
	render_scale = clampf(s, 0.25, 1.0)
	_apply_size()


func request_frame() -> void:
	if _viewport == null:
		return  # setup() may run before _ready wires the SubViewport
	if continuous:
		return  # never downgrade UPDATE_ALWAYS to UPDATE_ONCE mid-motion
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_continuous(on: bool) -> void:
	continuous = on
	if _viewport == null:
		return
	_viewport.render_target_update_mode = \
		SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


## Returns the window pixel of `point`, or null when it is behind the camera.
func project(point: Vector3) -> Variant:
	var rel := point - _camera.eye()
	var z_c := rel.dot(_camera.forward())
	if z_c <= 0.0:
		return null
	var x_c := rel.dot(_camera.right())
	var y_c := rel.dot(_camera.up())
	var a := _aspect()
	var ndc_x := (x_c / z_c) / (a * TAN_HALF_FOV)
	var ndc_y := (y_c / z_c) / TAN_HALF_FOV
	var uv := Vector2(ndc_x * 0.5 + 0.5, 0.5 - ndc_y * 0.5)
	return uv * size


## The world point at camera-forward depth `depth` under window `pixel`.
func unproject(pixel: Vector2, depth: float) -> Vector3:
	var uv := pixel / size
	var ndc_x := (uv.x - 0.5) * 2.0
	var ndc_y := -(uv.y - 0.5) * 2.0
	var a := _aspect()
	var d := _camera.forward() \
		+ ndc_x * a * TAN_HALF_FOV * _camera.right() \
		+ ndc_y * TAN_HALF_FOV * _camera.up()
	return _camera.eye() + d * depth


func _aspect() -> float:
	return size.x / maxf(size.y, 1.0)


func _apply_size() -> void:
	if _viewport == null:
		return  # setup()/set_render_scale() may run before _ready
	var px := Vector2i(maxi(1, int(round(size.x * render_scale))),
		maxi(1, int(round(size.y * render_scale))))
	_viewport.size = px
	_rect.size = Vector2(px)
	if _material:
		_material.set_shader_parameter("aspect", _aspect())


func _on_params_changed() -> void:
	_push_params()
	request_frame()


func _on_camera_changed() -> void:
	_push_camera()
	request_frame()


func _push_params() -> void:
	if _material == null or _params == null:
		return
	_material.set_shader_parameter("scale", _params.scale)
	_material.set_shader_parameter("min_r2", _params.inner_radius * _params.inner_radius)
	_material.set_shader_parameter("fixed_r2", _params.outer_radius * _params.outer_radius)
	_material.set_shader_parameter("fold_limit", _params.fold_limit)
	_material.set_shader_parameter("precision", _params.precision)
	_material.set_shader_parameter("color_mode", _params.color_mode)
	_material.set_shader_parameter("julia_enabled", _params.julia_enabled)
	_material.set_shader_parameter("julia_point", _params.julia_point)
	_material.set_shader_parameter("tan_half_fov", TAN_HALF_FOV)
	_material.set_shader_parameter("box_half", 20.0 if _params.julia_enabled else 2.0)


func _push_camera() -> void:
	if _material == null or _camera == null:
		return
	_material.set_shader_parameter("eye", _camera.eye())
	_material.set_shader_parameter("cam_right", _camera.right())
	_material.set_shader_parameter("cam_up", _camera.up())
	_material.set_shader_parameter("cam_forward", _camera.forward())
