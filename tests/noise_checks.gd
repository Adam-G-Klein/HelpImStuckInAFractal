class_name NoiseNodeChecks
extends RefCounted
## Schema assertions shared by the noise node tests:
##   NoiseNodeChecks.check_type(self, type)
## Mirrors Fractacular's IsolationNodeChecks, minus the render-pass contract — a
## noise node emits GLSL, it has no shaders of its own. Every message is prefixed
## with the type id, so a failure names the node.
##
## What it asserts: id, title, description and group present; a well-formed
## PortSpec per port; every parameter with a tooltip, an effects line, a default
## inside its slider range and a hard range containing it; unique parameter ids;
## well-formed enums; new_table() holding every parameter; and extras that are
## JSON-native (a Color in extras would make the save write null).


static func check_type(test, type: NoiseNodeType) -> void:
	test.check(type != null, "a type was built (the registry instanced it?)")
	if type == null:
		return
	test.check(type.id != &"" and type.title != "", "%s: has id and title" % type.id)
	test.check(type.description != "", "%s: has a description (its own tooltip)" % type.id)
	test.check(type.group != "", "%s: has an add-menu group" % type.id)

	for i in type.inputs.size():
		_check_port(test, type, type.inputs[i], "input %d" % i)
	for i in type.outputs.size():
		_check_port(test, type, type.outputs[i], "output %d" % i)

	var specs := type.params()
	var seen := {}
	for s in specs:
		test.check(s != null, "%s: every spec was built (make() returned null?)" % type.id)
		if s == null:
			continue
		test.check(not seen.has(s.id), "%s: param id '%s' is unique" % [type.id, s.id])
		seen[s.id] = true
		test.check(s.tooltip != "" and s.effects != "",
			"%s: '%s' has tooltip and effects" % [type.id, s.id])
		if s.type == NoiseParamSpec.Type.FLOAT or s.type == NoiseParamSpec.Type.INT:
			var v := float(s.default_value)
			test.check(v >= s.min_value and v <= s.max_value,
				"%s: '%s' default %s inside [%s, %s]" % [type.id, s.id, v, s.min_value, s.max_value])
			test.check(s.hard_min <= s.min_value and s.hard_max >= s.max_value,
				"%s: '%s' hard range contains slider range" % [type.id, s.id])
		if s.type == NoiseParamSpec.Type.ENUM:
			test.check(s.enum_labels.size() > 0 and s.enum_values.size() == s.enum_labels.size(),
				"%s: '%s' enum has labels and matching values" % [type.id, s.id])
			test.check(s.enum_values.has(int(s.default_value)),
				"%s: '%s' enum default is a listed value" % [type.id, s.id])
	test.check(type.new_table().specs.size() == specs.size(),
		"%s: new_table() holds every parameter" % type.id)

	var extras := type.extras_default()
	test.check(JSON.stringify(extras) != "", "%s: extras_default() serialises as JSON" % type.id)
	_check_json_native(test, type, extras, "extras")


static func _check_port(test, type: NoiseNodeType, p: NoiseNodeType.PortSpec, where: String) -> void:
	test.check(p != null, "%s: %s was built" % [type.id, where])
	if p == null:
		return
	test.check(p.name != "", "%s: %s has a name" % [type.id, where])
	test.check(p.tooltip != "", "%s: %s ('%s') has a tooltip" % [type.id, where, p.name])
	test.check(p.type >= 0 and p.type < NoisePort.NAMES.size(),
		"%s: %s ('%s') has a valid port type" % [type.id, where, p.name])


static func _check_json_native(test, type: NoiseNodeType, value: Variant, path: String) -> void:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return
		TYPE_DICTIONARY:
			var d: Dictionary = value
			for key in d:
				test.check(key is String or key is StringName,
					"%s: %s key '%s' is a string" % [type.id, path, key])
				_check_json_native(test, type, d[key], "%s.%s" % [path, key])
		TYPE_ARRAY:
			var a: Array = value
			for i in a.size():
				_check_json_native(test, type, a[i], "%s[%d]" % [path, i])
		_:
			test.check(false,
				"%s: %s is JSON-native, not a %s (use from_color() for a colour)"
					% [type.id, path, type_string(typeof(value))])
