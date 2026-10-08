class_name AxisController
extends Node
## Reads the keymap's InputMap actions every frame and pushes the axes. The only
## place in the movement layer that touches Godot's input system. While a text
## field has keyboard focus in any of the viewports it was given (the main
## window's and the console's), every key is ignored, so typing "e" into a spin
## box never moves an axis.

var _keymap: Keymap
var _viewports: Array = []


## `viewports` are the viewports whose text focus should silence the keys.
func setup(keymap: Keymap, viewports: Array) -> void:
	_keymap = keymap
	_viewports = viewports


func _process(delta: float) -> void:
	if _keymap == null:
		return
	if TextFocus.any(_viewports):
		return
	for a in _keymap.axes().list():
		var direction := Input.get_action_strength(_keymap.pos_action(a.id)) \
			- Input.get_action_strength(_keymap.neg_action(a.id))
		if direction != 0.0:
			_keymap.axes().step(a.id, direction, delta)
