class_name NoiseParamRow
extends HBoxContainer
## One knob in a noise node's GraphNode: a label and a value widget — a slider and
## spin box for FLOAT/INT, an OptionButton for ENUM, a CheckBox for BOOL.
##
## A port of Fractacular's AttributeRow compact form with the four binding widgets
## removed: a noise field has no movement point, so there is nothing to bind to.
## Every edit goes through the NoiseParamTable, which emits `changed`; the row then
## re-reads itself in refresh(). `_updating` guards that round trip.

const LABEL_MIN_WIDTH := 86.0
const SPIN_WIDTH := 64.0

var spec: NoiseParamSpec

var _table: NoiseParamTable
var _label: Label
var _slider: HSlider
var _spin: SpinBox
var _check: CheckBox
var _option: OptionButton
var _updating := false


## Build the row for one parameter of one table. Call before adding it to a parent.
func setup(parameter: NoiseParamSpec, table: NoiseParamTable) -> void:
	spec = parameter
	_table = table
	add_theme_constant_override("separation", 4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_label()
	_build_value()
	_table.changed.connect(_on_table_changed)
	refresh()


## Re-read every widget from the table: value, visibility and enabled state.
func refresh() -> void:
	if _table == null or spec == null:
		return
	_updating = true
	var values := _table.values()
	visible = spec.is_shown(values)
	var enabled := spec.is_enabled(values)
	var value: Variant = _table.get_value(spec.id)
	if _slider != null:
		_slider.value = _to_slider(float(value))
		_slider.editable = enabled
	if _spin != null:
		_spin.value = float(value)
		_spin.editable = enabled
	if _check != null:
		_check.button_pressed = bool(value)
		_check.disabled = not enabled
	if _option != null:
		_select_id(_option, int(value))
		_option.disabled = not enabled
	_updating = false


func value_control() -> Control:
	if _slider != null:
		return _slider
	if _check != null:
		return _check
	return _option


func spin_box() -> SpinBox:
	return _spin


func option_button() -> OptionButton:
	return _option


func check_box() -> CheckBox:
	return _check


# ----------------------------------------------------------------- building

func _build_label() -> void:
	_label = Label.new()
	_label.text = spec.label + (" (log)" if spec.log_scale else "")
	var tip := spec.tooltip + "\n\n" + spec.effects
	if spec.log_scale:
		tip += "\n\nThe slider is logarithmic: equal distances are equal ratios."
	if spec.wrap:
		tip += "\n\nThis value wraps: past the end of the range it reappears at the other end."
	_label.tooltip_text = tip
	_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_label.custom_minimum_size = Vector2(LABEL_MIN_WIDTH, 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func _build_value() -> void:
	match spec.type:
		NoiseParamSpec.Type.FLOAT, NoiseParamSpec.Type.INT:
			_slider = HSlider.new()
			_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_slider.scrollable = false
			if spec.log_scale:
				_slider.min_value = 0.0
				_slider.max_value = 1.0
				_slider.step = 0.001
			else:
				_slider.min_value = spec.min_value
				_slider.max_value = spec.max_value
				_slider.step = spec.step
			_slider.tooltip_text = "Drag to set %s between %s and %s." % [
				spec.label, _num(spec.min_value), _num(spec.max_value)]
			_slider.value_changed.connect(_on_slider_changed)
			add_child(_slider)

			_spin = SpinBox.new()
			_spin.min_value = spec.hard_min
			_spin.max_value = spec.hard_max
			_spin.step = spec.step
			_spin.custom_minimum_size = Vector2(SPIN_WIDTH, 0)
			_spin.tooltip_text = "Type an exact value. The slider covers %s … %s; typing is allowed out to %s … %s." % [
				_num(spec.min_value), _num(spec.max_value), _num(spec.hard_min), _num(spec.hard_max)]
			_spin.value_changed.connect(_on_spin_changed)
			add_child(_spin)
		NoiseParamSpec.Type.BOOL:
			_check = CheckBox.new()
			_check.text = "on"
			_check.tooltip_text = "Turn %s on or off. %s" % [spec.label, spec.tooltip]
			_check.toggled.connect(_on_check_toggled)
			add_child(_check)
		NoiseParamSpec.Type.ENUM:
			_option = OptionButton.new()
			_option.custom_minimum_size = Vector2(SPIN_WIDTH, 0)
			_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for i in spec.enum_labels.size():
				_option.add_item(spec.enum_labels[i], spec.enum_values[i])
			_option.tooltip_text = "%s\n\n%s" % [spec.tooltip, spec.effects]
			_option.item_selected.connect(_on_option_selected)
			add_child(_option)


# ------------------------------------------------------------------ editing

func _on_table_changed(_id: StringName) -> void:
	refresh()


func _on_slider_changed(value: float) -> void:
	if not _updating:
		_table.set_value(spec.id, _from_slider(value))


func _on_spin_changed(value: float) -> void:
	if not _updating:
		_table.set_value(spec.id, value)


func _on_check_toggled(pressed: bool) -> void:
	if not _updating:
		_table.set_value(spec.id, pressed)


func _on_option_selected(index: int) -> void:
	if not _updating:
		_table.set_value(spec.id, _option.get_item_id(index))


# ------------------------------------------------------------------ helpers

func _select_id(option: OptionButton, id: int) -> void:
	for i in option.item_count:
		if option.get_item_id(i) == id:
			option.select(i)
			return


func _to_slider(value: float) -> float:
	if not spec.log_scale:
		return value
	var lo := log(maxf(spec.min_value, 1e-9))
	var hi := log(maxf(spec.max_value, 1e-9))
	if hi <= lo:
		return 0.0
	return clampf((log(maxf(value, 1e-9)) - lo) / (hi - lo), 0.0, 1.0)


func _from_slider(t: float) -> float:
	if not spec.log_scale:
		return t
	var lo := log(maxf(spec.min_value, 1e-9))
	var hi := log(maxf(spec.max_value, 1e-9))
	return exp(lerpf(lo, hi, clampf(t, 0.0, 1.0)))


func _num(value: float) -> String:
	return String.num(value, 4)
