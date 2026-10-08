class_name SettingsMenu
extends VBoxContainer
## The settings page shared by the main menu and the pause menu. Edits the
## Settings autoload directly; `back` asks the owner to show its own list again.

signal back

var sens_slider: HSlider
var sens_value: Label
var back_button: Button


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = "Mouse sensitivity"
	sens_slider = HSlider.new()
	sens_slider.min_value = Settings.SENSITIVITY_MIN
	sens_slider.max_value = Settings.SENSITIVITY_MAX
	sens_slider.step = 0.001
	sens_slider.custom_minimum_size = Vector2(240, 0)
	sens_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sens_value = Label.new()
	sens_value.custom_minimum_size = Vector2(56, 0)
	row.add_child(label)
	row.add_child(sens_slider)
	row.add_child(sens_value)
	add_child(row)

	back_button = MenuButtons.make("Back")
	add_child(back_button)

	sens_slider.value_changed.connect(func(v): Settings.mouse_sensitivity = v)
	back_button.pressed.connect(back.emit)


func _ready() -> void:
	Settings.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	sens_slider.set_value_no_signal(Settings.mouse_sensitivity)
	sens_value.text = "%.3f" % Settings.mouse_sensitivity
