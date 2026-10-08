class_name NoiseParamTable
extends RefCounted
## Per-node parameter state: an ordered list of specs and a value for each. Emits
## `changed(id)` whenever a value is edited, so the view and the editor can
## re-render on change instead of every frame.
##
## A port of Fractacular's AttributeTable with its bindings dropped.

signal changed(id: StringName)

var specs: Array[NoiseParamSpec] = []
var _by_id: Dictionary = {}
var _defaults: Dictionary = {}


func _init(spec_list: Array[NoiseParamSpec] = []) -> void:
	for s in spec_list:
		_add(s)


func _add(s: NoiseParamSpec) -> void:
	if _by_id.has(s.id):
		push_error("NoiseParamTable: duplicate param id '%s'" % s.id)
		return
	specs.append(s)
	_by_id[s.id] = s
	_defaults[s.id] = s.default_value


func has(id: StringName) -> bool:
	return _by_id.has(id)


func spec(id: StringName) -> NoiseParamSpec:
	return _by_id.get(id)


## Param ids in declaration order.
func ids() -> Array:
	return specs.map(func(s: NoiseParamSpec) -> StringName: return s.id)


func get_value(id: StringName) -> Variant:
	return _defaults.get(id)


## Sanitizes through the spec, stores, and emits `changed` if it differs.
func set_value(id: StringName, value: Variant) -> void:
	var s := spec(id)
	if s == null:
		push_warning("NoiseParamTable.set_value: unknown id '%s'" % id)
		return
	var v: Variant = s.sanitize(value)
	if v == _defaults[id]:
		return
	_defaults[id] = v
	changed.emit(id)


## A copy of every value, keyed by id.
func values() -> Dictionary:
	return _defaults.duplicate()


func duplicate() -> NoiseParamTable:
	var t := NoiseParamTable.new(specs)
	for id in _defaults:
		t._defaults[id] = _defaults[id]
	return t


## JSON-friendly: String keys.
func to_dict() -> Dictionary:
	var d := {}
	for id in _defaults:
		d[String(id)] = _defaults[id]
	return d


## Apply a dictionary from `to_dict()`. Unknown ids are skipped; one warning
## string per skipped id is returned.
func apply_dict(d: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	for key in d:
		var id := StringName(key)
		if not has(id):
			warnings.append("Unknown parameter '%s' ignored" % key)
			continue
		set_value(id, d[key])
	return warnings
