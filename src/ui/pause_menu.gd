class_name PauseMenu
extends CanvasLayer
## Escape's menu: dims the view over Resume, Settings and Back to Menu. Main
## pauses the tree and shows it; it keeps running while paused and hands the
## choice back through its signals. Escape inside it steps back out. On the
## settings' Renderer tab the dim lightens, so the view shows each change.

signal resume_requested
signal menu_requested

const DIM := 0.6
const DIM_RENDERER := 0.15

var resume_button: Button
var settings_button: Button
var menu_button: Button
var settings_menu: SettingsMenu
var dim: ColorRect

var _list: VBoxContainer


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, DIM)
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
	settings_menu.renderer_shown.connect(func(on): dim.color.a = DIM_RENDERER if on else DIM)


func open() -> void:
	show_settings(false)
	visible = true
	resume_button.grab_focus()


func close() -> void:
	visible = false


func show_settings(on: bool) -> void:
	_list.visible = not on
	settings_menu.visible = on
	if visible:
		(settings_menu.back_button if on else settings_button).grab_focus()


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
