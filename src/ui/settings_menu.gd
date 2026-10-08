class_name SettingsMenu
extends VBoxContainer
## The settings page shared by the main menu and the pause menu, as two tabs.
## Controls edits the Settings autoload directly. Renderer edits the open view's
## FractalParams, so it is only enabled once set_params() hands it a view (the
## pause menu does; the main menu has no view). `back` asks the owner to show its
## own list again.

signal back
## The Renderer tab was shown or hidden (the pause menu lightens its dim for it).
signal renderer_shown(on: bool)

const CONTROLS_TAB := 0
const RENDERER_TAB := 1

var tabs: TabContainer
var sens_slider: HSlider
var sens_value: Label
var renderer: RendererOptions
var back_button: Button


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(600, 0)
	var panel := StyleBoxFlat.new()   # padded, and dark enough to read over the view
	panel.bg_color = Color(0, 0, 0, 0.6)
	panel.set_content_margin_all(16)
	panel.set_corner_radius_all(4)
	tabs.add_theme_stylebox_override("panel", panel)
	add_child(tabs)

	var controls := VBoxContainer.new()
	controls.name = "Controls"
	var row := HBoxContainer.new()
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
	controls.add_child(row)
	tabs.add_child(controls)

	renderer = RendererOptions.new()
	tabs.add_child(renderer)
	tabs.set_tab_disabled(RENDERER_TAB, true)
	tabs.set_tab_tooltip(RENDERER_TAB, "Renderer options belong to the open view: open them from the pause menu (Esc) while exploring.")

	back_button = MenuButtons.make("Back")
	add_child(back_button)

	sens_slider.value_changed.connect(func(v): Settings.mouse_sensitivity = v)
	back_button.pressed.connect(back.emit)
	tabs.tab_changed.connect(func(_i): renderer_shown.emit(renderer_active()))
	visibility_changed.connect(func(): renderer_shown.emit(renderer_active()))


func _ready() -> void:
	Settings.changed.connect(_refresh)
	_refresh()


## Hand the Renderer tab the open view's params, which enables it.
func set_params(params: FractalParams) -> void:
	renderer.setup(params)
	tabs.set_tab_disabled(RENDERER_TAB, false)
	tabs.set_tab_tooltip(RENDERER_TAB, "")


## True while this page is shown on its Renderer tab.
func renderer_active() -> bool:
	return visible and tabs.current_tab == RENDERER_TAB


func _refresh() -> void:
	sens_slider.set_value_no_signal(Settings.mouse_sensitivity)
	sens_value.text = "%.3f" % Settings.mouse_sensitivity
