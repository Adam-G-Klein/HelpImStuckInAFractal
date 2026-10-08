class_name Axes
extends RefCounted
## The virtual axes of the movement layer: an ordered list of axes, each with an
## id, a label, a push speed and an unbounded value. Key pairs push a value at
## its speed; a binding reads the value through `values()`. This holds no input
## code and no drawing — Keymap maps keys to it, AxisController pushes it.

signal changed


class Axis:
	var id: StringName
	var label: String
	var speed: float
	var value: float

	func _init(p_id: StringName, p_label: String, p_speed: float, p_value: float = 0.0) -> void:
		id = p_id
		label = p_label
		speed = p_speed
		value = p_value


var _list: Array[Axis] = []
var _by_id: Dictionary = {}


func has(id: StringName) -> bool:
	return _by_id.has(id)


## Add an axis, or do nothing (with a warning) if the id is taken.
func add(id: StringName, label: String, speed: float) -> void:
	if _by_id.has(id):
		push_warning("Axes.add: duplicate id '%s'" % id)
		return
	var axis := Axis.new(id, label, speed)
	_list.append(axis)
	_by_id[id] = axis
	changed.emit()


func remove(id: StringName) -> void:
	if not _by_id.has(id):
		return
	_list.erase(_by_id[id])
	_by_id.erase(id)
	changed.emit()


func clear() -> void:
	_list.clear()
	_by_id.clear()
	changed.emit()


## The axes in order.
func list() -> Array[Axis]:
	return _list


func ids() -> Array:
	return _list.map(func(a: Axis) -> StringName: return a.id)


func label(id: StringName) -> String:
	return _by_id[id].label if _by_id.has(id) else ""


func set_label(id: StringName, text: String) -> void:
	if _by_id.has(id):
		_by_id[id].label = text
		changed.emit()


func speed(id: StringName) -> float:
	return _by_id[id].speed if _by_id.has(id) else 0.0


func set_speed(id: StringName, v: float) -> void:
	if _by_id.has(id):
		_by_id[id].speed = v
		changed.emit()


func value(id: StringName) -> float:
	return _by_id[id].value if _by_id.has(id) else 0.0


## Set an axis value directly (loads, game code, the "0" button).
func set_value(id: StringName, v: float) -> void:
	if _by_id.has(id):
		_by_id[id].value = v
		changed.emit()


## Push an axis by `direction * speed * delta`. `direction` is -1, 0 or +1.
func step(id: StringName, direction: float, delta: float) -> void:
	if not _by_id.has(id) or direction == 0.0:
		return
	var axis: Axis = _by_id[id]
	axis.value += direction * axis.speed * delta
	changed.emit()


## Every axis value by id, for the resolver and for saves.
func values() -> Dictionary:
	var out := {}
	for a in _list:
		out[a.id] = a.value
	return out
