class_name CtrlTap
extends RefCounted
## The arm/disarm Ctrl-tap detector, shared by Main and the console. Ctrl is
## also a chord modifier (Cmd/Ctrl+S saves, Ctrl+P screenshots), so a tap must
## fire on *release* and only when Ctrl was tapped alone:
##   - a bare non-echo Ctrl key-down arms (unless a text field is focused),
##   - any other key-down while armed disarms,
##   - a Ctrl key-up while armed fires.
## `feed(event)` returns true exactly when a tap fires; the caller then acts and
## consumes the event. Main runs one against the main window; the console runs
## one against its own window.

## Optional `Callable() -> bool`: true while a text field is focused, so a tap
## never arms mid-typing.
var typing_guard: Callable = Callable()

var _armed := false


func feed(event: InputEvent) -> bool:
	if not (event is InputEventKey) or event.echo:
		return false
	var k := event as InputEventKey
	if k.physical_keycode == KEY_CTRL:
		if k.pressed:
			_armed = not _typing()
		elif _armed:
			_armed = false
			return true
	elif k.pressed:
		_armed = false   # any other key pressed while Ctrl is held disarms
	return false


func is_armed() -> bool:
	return _armed


func _typing() -> bool:
	return typing_guard.is_valid() and bool(typing_guard.call())
