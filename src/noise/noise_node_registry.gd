class_name NoiseNodeRegistry
extends RefCounted
## Every noise node type, from a list of preloaded scripts: one per file in
## src/noise/nodes. Adding a node type means dropping `<id>.gd` in that directory
## AND adding it to NODE_SCRIPTS (kept in file-name order).
##
## It used to scan the directory instead, which only works when the project is
## run from source: an exported .pck holds compiled .gdc files, so the web build
## found no nodes at all. noise_registry_test.gd lists the directory (which works
## from source) and fails if a file is missing here, so a new node still cannot
## be forgotten silently.

const NODE_DIR := "res://src/noise/nodes"

const NODE_SCRIPTS: Array[GDScript] = [
	preload("res://src/noise/nodes/cellular.gd"),
	preload("res://src/noise/nodes/clamp.gd"),
	preload("res://src/noise/nodes/combine_xyz.gd"),
	preload("res://src/noise/nodes/constant.gd"),
	preload("res://src/noise/nodes/gradient_noise.gd"),
	preload("res://src/noise/nodes/length.gd"),
	preload("res://src/noise/nodes/math.gd"),
	preload("res://src/noise/nodes/mix.gd"),
	preload("res://src/noise/nodes/output.gd"),
	preload("res://src/noise/nodes/position.gd"),
	preload("res://src/noise/nodes/remap.gd"),
	preload("res://src/noise/nodes/split_xyz.gd"),
	preload("res://src/noise/nodes/transform.gd"),
	preload("res://src/noise/nodes/value_noise.gd"),
	preload("res://src/noise/nodes/warp.gd"),
]


## Fresh instances, sorted by (order, title). Fresh, not cached: instancing a
## dozen RefCounteds is free and two editors sharing one instance is a subtle bug.
static func all() -> Array[NoiseNodeType]:
	var out: Array[NoiseNodeType] = []
	for script in NODE_SCRIPTS:
		var instance: Variant = script.new()
		if not (instance is NoiseNodeType):
			push_warning("NoiseNodeRegistry: %s is not a NoiseNodeType" % script.resource_path)
			continue
		var type: NoiseNodeType = instance
		if type.id == &"":
			push_warning("NoiseNodeRegistry: %s has no id" % script.resource_path)
			continue
		out.append(type)
	out.sort_custom(func(a: NoiseNodeType, b: NoiseNodeType) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return a.title < b.title)
	return out


static func type_by_id(id: StringName) -> NoiseNodeType:
	for t in all():
		if t.id == id:
			return t
	return null


static func has_type(id: StringName) -> bool:
	for t in all():
		if t.id == id:
			return true
	return false


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for t in all():
		out.append(t.id)
	return out


## Each distinct `group` in all()'s order, deduplicated: the order the add menu
## lists its submenus in.
static func groups() -> Array[String]:
	var out: Array[String] = []
	for t in all():
		if t.group != "" and not out.has(t.group):
			out.append(t.group)
	return out
