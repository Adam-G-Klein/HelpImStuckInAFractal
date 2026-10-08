class_name ControlsPanel
extends PanelContainer
## The Q panel. Edits FractalParams and camera settings; mirrors external
## changes. Never touches the shader or the viewport.

var scale_slider: HSlider
var inner_slider: HSlider
var fold_slider: HSlider
var outer_slider: HSlider
var color_option: OptionButton
var precision_edit: LineEdit
var julia_check: CheckBox
var julia_x: LineEdit
var julia_y: LineEdit
var julia_z: LineEdit
var julia_row: HBoxContainer
var fast_check: CheckBox
var camera_option: OptionButton
var sens_slider: HSlider
var speed_label: Label
var legend_label: Label
var save_button: Button
var load_button: Button
var noise_button: Button
var file_label: Label
var status_label: Label

var _params: FractalParams
var _camera: CameraState
var _syncing := false
var _built := false


## Build the widgets. Called from setup() (not _ready) so the panel is fully
## constructed before the first refresh, regardless of _ready timing.
func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var box := VBoxContainer.new()
	add_child(box)

	var files_row := HBoxContainer.new()
	save_button = Button.new()
	save_button.text = "Save"
	save_button.tooltip_text = "Save the shape, colour and camera to a file in saves/ (Cmd+S overwrites the current file)"
	load_button = Button.new()
	load_button.text = "Load"
	load_button.tooltip_text = "Load a saved view from saves/"
	file_label = Label.new()
	file_label.clip_text = true
	file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	files_row.add_child(save_button)
	files_row.add_child(load_button)
	files_row.add_child(file_label)
	box.add_child(files_row)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.visible = false
	box.add_child(status_label)
	show_file("")

	scale_slider = _labeled_slider(box, "Slice (Scale)", -5.0, -0.5, 0.01)
	inner_slider = _labeled_slider(box, "Inner Radius", 0.0, 1.0, 0.01)
	fold_slider = _labeled_slider(box, "Fold", 0.0, 1.0, 0.01)
	outer_slider = _labeled_slider(box, "Outer Radius", 0.0, 1.0, 0.01)

	color_option = OptionButton.new()
	for i in FractalParams.COLOR_MODE_NAMES.size():
		color_option.add_item(FractalParams.COLOR_MODE_NAMES[i], i)
	box.add_child(_row("Color", color_option))

	precision_edit = LineEdit.new()
	box.add_child(_row("Precision", precision_edit))

	julia_check = CheckBox.new()
	julia_check.text = "Julia"
	box.add_child(julia_check)
	julia_row = HBoxContainer.new()
	julia_x = _coord_edit(julia_row, "X")
	julia_y = _coord_edit(julia_row, "Y")
	julia_z = _coord_edit(julia_row, "Z")
	box.add_child(julia_row)

	fast_check = CheckBox.new()
	fast_check.text = "Fast Controls"
	box.add_child(fast_check)

	camera_option = OptionButton.new()
	camera_option.add_item("Fly", 0)
	camera_option.add_item("Orbit", 1)
	box.add_child(_row("Camera", camera_option))

	sens_slider = _labeled_slider(box, "Mouse sensitivity", 0.02, 0.5, 0.001)

	noise_button = Button.new()
	noise_button.text = "Noise editor…"
	noise_button.tooltip_text = "Open the noise-field editor (also the N key): author a 3D noise field as a node graph and see it displace and tint the fractal live."
	box.add_child(noise_button)

	speed_label = Label.new()
	box.add_child(speed_label)
	legend_label = Label.new()
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(legend_label)

	# writes
	scale_slider.value_changed.connect(func(v): _write(func(): _params.scale = v))
	inner_slider.value_changed.connect(func(v): _write(func(): _params.inner_radius = v))
	fold_slider.value_changed.connect(func(v): _write(func(): _params.fold_limit = v))
	outer_slider.value_changed.connect(func(v): _write(func(): _params.outer_radius = v))
	color_option.item_selected.connect(func(i): _write(func(): _params.color_mode = FractalParams.COLOR_MODE_IDS[i]))
	precision_edit.text_submitted.connect(_on_precision_submitted)
	precision_edit.focus_exited.connect(func(): _on_precision_submitted(precision_edit.text))
	julia_check.toggled.connect(func(on): _write(func(): _params.julia_enabled = on); _refresh())
	for e in [julia_x, julia_y, julia_z]:
		e.text_submitted.connect(func(_t): _on_julia_submitted())
		e.focus_exited.connect(_on_julia_submitted)
	fast_check.toggled.connect(func(on): _write(func(): _params.fast_controls = on))
	camera_option.item_selected.connect(func(i): _write(func(): _params.camera_mode = i))
	sens_slider.value_changed.connect(func(v): _write(func(): _params.mouse_sensitivity = v))


func setup(params: FractalParams, camera: CameraState) -> void:
	_params = params
	_camera = camera
	_build()
	params.changed.connect(_refresh)
	camera.changed.connect(_refresh)
	_refresh()


## The current save's name, or an em dash when there is none.
func show_file(display_name: String) -> void:
	file_label.text = display_name if display_name != "" else "\u2014"


## One line about the last save or load; "" hides it.
func show_status(text: String) -> void:
	status_label.text = text
	status_label.visible = text != ""


## True while any text field in the panel holds keyboard focus (so Main can
## ignore Q and let the user type a value containing "q").
func text_field_has_focus() -> bool:
	for e in [precision_edit, julia_x, julia_y, julia_z]:
		if e.has_focus():
			return true
	return false


func _write(action: Callable) -> void:
	if _syncing:
		return
	action.call()


func _on_precision_submitted(text: String) -> void:
	if _syncing:
		return
	if text.is_valid_float() and text.to_float() > 0.0:
		_params.precision = text.to_float()
	else:
		precision_edit.text = str(_params.precision)   # revert


func _on_julia_submitted() -> void:
	if _syncing:
		return
	var p := _params.julia_point
	if julia_x.text.is_valid_float(): p.x = julia_x.text.to_float()
	if julia_y.text.is_valid_float(): p.y = julia_y.text.to_float()
	if julia_z.text.is_valid_float(): p.z = julia_z.text.to_float()
	_params.julia_point = p


func _refresh() -> void:
	if _params == null:
		return
	_syncing = true
	scale_slider.value = _params.scale
	inner_slider.value = _params.inner_radius
	fold_slider.value = _params.fold_limit
	outer_slider.value = _params.outer_radius
	color_option.select(FractalParams.COLOR_MODE_IDS.find(_params.color_mode))
	if not precision_edit.has_focus():
		precision_edit.text = str(_params.precision)
	julia_check.button_pressed = _params.julia_enabled
	julia_row.visible = _params.julia_enabled
	if not julia_x.has_focus(): julia_x.text = str(_params.julia_point.x)
	if not julia_y.has_focus(): julia_y.text = str(_params.julia_point.y)
	if not julia_z.has_focus(): julia_z.text = str(_params.julia_point.z)
	fast_check.button_pressed = _params.fast_controls
	camera_option.select(_params.camera_mode)
	sens_slider.value = _params.mouse_sensitivity
	if _params.camera_mode == FractalParams.CameraMode.FLY and _camera != null:
		speed_label.text = "speed x%.2f" % _camera.speed_factor
		legend_label.text = "Q panel - WASD fly - Space/Shift up/down - wheel speed - click to capture mouse"
	else:
		speed_label.text = ""
		legend_label.text = "Q panel - left-drag orbit - Shift-drag pan - right-drag dolly - wheel zoom"
	_syncing = false


func _labeled_slider(box: VBoxContainer, label: String, lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.custom_minimum_size = Vector2(180, 0)
	box.add_child(_row(label, s))
	return s


func _row(label: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l); h.add_child(control)
	return h


func _coord_edit(row: HBoxContainer, label: String) -> LineEdit:
	var l := Label.new(); l.text = label
	var e := LineEdit.new(); e.custom_minimum_size = Vector2(70, 0)
	row.add_child(l); row.add_child(e)
	return e
