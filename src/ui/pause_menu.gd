class_name PauseMenu
extends CanvasLayer
## Escape's menu: dims the view over a controls block (Save/Load view, Camera,
## Fast Controls, Noise editor) and Resume / Settings / Back to Menu. Main
## pauses the tree and shows it; it keeps running while paused and hands the
## choice back through its signals. Escape inside it steps back out.
##
## The controls that used to live in the Q panel but are not shape knobs moved
## here: the file row (Save/Load + current name + status), the camera mode, Fast
## Controls, and the Noise editor button. The shape knobs are in the console.

signal resume_requested
signal menu_requested
signal save_requested
signal load_requested
signal noise_requested

var resume_button: Button
var settings_button: Button
var menu_button: Button
var save_button: Button
var load_button: Button
var noise_button: Button
var camera_option: OptionButton
var fast_check: CheckBox
var file_label: Label
var status_label: Label
var settings_menu: SettingsMenu

var _params: FractalParams
var _list: VBoxContainer
var _syncing := false


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)   # also stops clicks reaching the view underneath

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	_list.add_child(title)

	_list.add_child(_build_controls())

	resume_button = MenuButtons.make("Resume")
	settings_button = MenuButtons.make("Settings")
	menu_button = MenuButtons.make("Back to Menu")
	for b in [resume_button, settings_button, menu_button]:
		_list.add_child(b)
	stack.add_child(_list)

	settings_menu = SettingsMenu.new()
	settings_menu.visible = false
	stack.add_child(settings_menu)

	resume_button.pressed.connect(resume_requested.emit)
	settings_button.pressed.connect(show_settings.bind(true))
	menu_button.pressed.connect(menu_requested.emit)
	settings_menu.back.connect(show_settings.bind(false))


## The file-row / camera / fast / noise block, styled smaller than the big
## menu buttons so it reads as a toolbar, not a choice.
func _build_controls() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var files_row := HBoxContainer.new()
	files_row.alignment = BoxContainer.ALIGNMENT_CENTER
	save_button = Button.new()
	save_button.text = "Save view…"
	save_button.tooltip_text = "Save the shape, bindings, axes, camera and preferences to a file in saves/ (Cmd/Ctrl+S overwrites the current file)."
	load_button = Button.new()
	load_button.text = "Load view…"
	load_button.tooltip_text = "Load a saved view from saves/."
	file_label = Label.new()
	file_label.custom_minimum_size = Vector2(160, 0)
	files_row.add_child(save_button)
	files_row.add_child(load_button)
	files_row.add_child(file_label)
	box.add_child(files_row)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.visible = false
	box.add_child(status_label)

	var camera_row := HBoxContainer.new()
	camera_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cam_label := Label.new(); cam_label.text = "Camera"
	camera_option = OptionButton.new()
	camera_option.add_item("Fly", 0)
	camera_option.add_item("Orbit", 1)
	camera_row.add_child(cam_label)
	camera_row.add_child(camera_option)
	box.add_child(camera_row)

	fast_check = CheckBox.new()
	fast_check.text = "Fast Controls"
	fast_check.tooltip_text = "Drop the render resolution while anything is moving to hold the frame rate, then snap back to full resolution when it stops."
	box.add_child(fast_check)

	noise_button = Button.new()
	noise_button.text = "Noise editor…"
	noise_button.tooltip_text = "Open the noise-field editor (also the N key): author a 3D noise field as a node graph and see it displace and tint the fractal live."
	box.add_child(noise_button)

	save_button.pressed.connect(save_requested.emit)
	load_button.pressed.connect(load_requested.emit)
	noise_button.pressed.connect(noise_requested.emit)
	camera_option.item_selected.connect(_on_camera_selected)
	fast_check.toggled.connect(_on_fast_toggled)
	show_file("")
	return box


## Wire the camera / fast controls to params. Call once from Main.
func setup(params: FractalParams) -> void:
	_params = params
	params.changed.connect(_refresh)
	_refresh()


func open() -> void:
	show_settings(false)
	visible = true
	resume_button.grab_focus()


func close() -> void:
	visible = false


## The current save's name, or an em dash when there is none.
func show_file(display_name: String) -> void:
	file_label.text = display_name if display_name != "" else "—"


## One line about the last save or load; "" hides it.
func show_status(text: String) -> void:
	status_label.text = text
	status_label.visible = text != ""


func show_settings(on: bool) -> void:
	_list.visible = not on
	settings_menu.visible = on
	if visible:
		(settings_menu.back_button if on else settings_button).grab_focus()


func _on_camera_selected(index: int) -> void:
	if _syncing or _params == null:
		return
	_params.camera_mode = index


func _on_fast_toggled(on: bool) -> void:
	if _syncing or _params == null:
		return
	_params.fast_controls = on


func _refresh() -> void:
	if _params == null:
		return
	_syncing = true
	camera_option.select(_params.camera_mode)
	fast_check.button_pressed = _params.fast_controls
	_syncing = false


## Main is paused while this is open, so Escape lands here: out of Settings
## first, then out of the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"pause"):
		return
	if settings_menu.visible:
		show_settings(false)
	else:
		resume_requested.emit()
	get_viewport().set_input_as_handled()
