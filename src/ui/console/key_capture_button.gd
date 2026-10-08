class_name KeyCaptureButton
extends Button
## A "press a key…" button that writes one physical key. Click it, then press a
## key: the physical keycode is captured and shown by name. Escape cancels and
## keeps the old key. KEY_NONE shows an em dash.

signal key_captured(keycode: int)

var _capturing := false
var _keycode := KEY_NONE


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_begin_capture)
	_update_text()


func set_key(keycode: int) -> void:
	_keycode = keycode
	_update_text()


func key() -> int:
	return _keycode


func is_capturing() -> bool:
	return _capturing


func _begin_capture() -> void:
	_capturing = true
	text = "press a key…"


## While capturing, the next physical key-down is the new key; Escape cancels.
func _input(event: InputEvent) -> void:
	if not _capturing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_capture(event.physical_keycode)
		get_viewport().set_input_as_handled()


## Capture directly (used by the input path and by tests). KEY_ESCAPE cancels.
func _capture(keycode: int) -> void:
	_capturing = false
	if keycode == KEY_ESCAPE:
		_update_text()
		return
	_keycode = keycode
	_update_text()
	key_captured.emit(_keycode)


func _update_text() -> void:
	text = OS.get_keycode_string(_keycode) if _keycode != KEY_NONE else "—"
