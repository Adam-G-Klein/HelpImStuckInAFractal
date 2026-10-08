class_name ConsoleWindow
extends Window
## The native second window ("Fractacular embedded"): an HSplit of the Shape
## inspector and the Movement pane, over the one Mandelbox shape being flown
## through in the main window. It is native because the project sets
## embed_subwindows = false; on the web that is ignored and it falls back to an
## embedded window. A Ctrl tap in this window forwards `toggle_requested`.

signal toggle_requested

const DEFAULT_SIZE := Vector2i(1000, 700)
const MIN_SIZE := Vector2i(700, 400)

var _inspector: AttributeInspector
var _movement: MovementPane
var _keymap: Keymap
var _ctrl := CtrlTap.new()


func setup(table: AttributeTable, keymap: Keymap, clock: Clock, group_tooltips: Dictionary, speed_source: Callable = Callable()) -> void:
	_keymap = keymap
	title = "Console"
	size = DEFAULT_SIZE
	min_size = MIN_SIZE
	unresizable = false
	wrap_controls = false
	visible = false
	close_requested.connect(hide_console)

	var split := HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)

	_inspector = AttributeInspector.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(_inspector)
	_inspector.setup(table, group_tooltips)

	_movement = MovementPane.new()
	_movement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_movement.setup(keymap, clock, speed_source)
	split.add_child(_movement)

	_ctrl.typing_guard = func() -> bool: return TextFocus.any([self])
	if keymap != null:
		keymap.changed.connect(_refresh_sources)
	_refresh_sources()


func inspector() -> AttributeInspector:
	return _inspector


func movement_pane() -> MovementPane:
	return _movement


## Feed one frame of resolved values to the Shape rows' readouts.
func set_resolved(values: Dictionary) -> void:
	if _inspector != null:
		_inspector.set_resolved(values)


func open() -> void:
	_center_in_parent()
	visible = true


func hide_console() -> void:
	visible = false


func toggle() -> void:
	if visible:
		hide_console()
	else:
		open()


## Feed a key event to the Ctrl-tap detector (also used directly by tests).
## Returns true when a tap fired.
func feed_ctrl(event: InputEvent) -> bool:
	if _ctrl.feed(event):
		toggle_requested.emit()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if feed_ctrl(event):
		set_input_as_handled()


func _refresh_sources() -> void:
	if _inspector == null or _keymap == null:
		return
	var axis_list: Array = []
	for axis in _keymap.axes().list():
		axis_list.append({"id": axis.id, "label": axis.label})
	_inspector.set_sources(axis_list)


func _center_in_parent() -> void:
	var base := DisplayServer.window_get_size()
	var parent := get_parent()
	if parent != null and parent.get_viewport() != null:
		base = Vector2i(parent.get_viewport().get_visible_rect().size)
	position = (base - size) / 2
