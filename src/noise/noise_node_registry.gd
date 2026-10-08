class_name NoiseNodeRegistry
extends RefCounted
## Every noise node type, found by SCANNING src/noise/nodes rather than by
## holding a list of scripts. Adding a node type means dropping `<id>.gd` in that
## directory — no edit here.
##
## The cost: DirAccess cannot enumerate a .pck, so this only works while the
## project is RUN FROM SOURCE, which is how it is run (run.sh, `--path .`). An
## export build would need the hard-coded list back — the same caveat as
## Fractacular's registry.

const NODE_DIR := "res://src/noise/nodes"


## Fresh instances, sorted by (order, title). Fresh, not cached: instancing a
## dozen RefCounteds is free and two editors sharing one instance is a subtle bug.
static func all() -> Array[NoiseNodeType]:
	var out: Array[NoiseNodeType] = []
	var dir := DirAccess.open(NODE_DIR)
	if dir == null:
		push_warning("NoiseNodeRegistry: cannot open %s" % NODE_DIR)
		return out
	var names := dir.get_files()
	names.sort()
	for file_name in names:
		if not file_name.ends_with(".gd"):
			continue
		var script: Variant = load("%s/%s" % [NODE_DIR, file_name])
		if not (script is GDScript):
			continue
		var instance: Variant = (script as GDScript).new()
		if not (instance is NoiseNodeType):
			push_warning("NoiseNodeRegistry: %s is not a NoiseNodeType" % file_name)
			continue
		var type: NoiseNodeType = instance
		if type.id == &"":
			push_warning("NoiseNodeRegistry: %s has no id" % file_name)
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
