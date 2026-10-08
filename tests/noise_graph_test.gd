extends "res://tests/test_case.gd"
## NoiseGraph: structure, legality, order and JSON. A true unit test: it injects a
## three-line fake node type and never loads the registry, which lets the model be
## checked without the node catalogue. A port of Fractacular's isolation_graph_test.


class FakePort extends RefCounted:
	var type: int = 0
	func _init(t: int) -> void:
		type = t


class FakeType extends RefCounted:
	var id: StringName
	var inputs: Array = []
	var outputs: Array = []
	var param_ids: Array = []

	func _init(type_id: StringName, in_types: Array, out_types: Array, params: Array = []) -> void:
		id = type_id
		for t in in_types:
			inputs.append(FakePort.new(t))
		for t in out_types:
			outputs.append(FakePort.new(t))
		param_ids = params

	func new_table() -> NoiseParamTable:
		var specs: Array[NoiseParamSpec] = []
		for pid in param_ids:
			specs.append(NoiseParamSpec.make({
				"id": pid, "label": String(pid),
				"type": NoiseParamSpec.Type.FLOAT, "default": 0.5,
				"min": 0.0, "max": 1.0, "step": 0.01,
				"tooltip": "fake", "effects": "fake"}))
		return NoiseParamTable.new(specs)


# Port types, matching NoisePort.Type without naming it.
const FLOAT := 0
const VEC3 := 1

var _types: Dictionary = {}


func _resolver(id: StringName) -> Variant:
	return _types.get(id, null)


func _build_types() -> void:
	# Position: no inputs, one Vec3 output.
	_types[&"position"] = FakeType.new(&"position", [], [VEC3])
	# Output: Displace (Float) and Tint (Float) inputs, no outputs.
	_types[&"output"] = FakeType.new(&"output", [FLOAT, FLOAT], [])
	# Value noise: Vec3 in, Float out, two params.
	_types[&"value_noise"] = FakeType.new(&"value_noise", [VEC3], [FLOAT], [&"scale", &"seed"])
	# Transform: Vec3 -> Vec3.
	_types[&"transform"] = FakeType.new(&"transform", [VEC3], [VEC3], [&"angle"])
	# Math: Float, Float -> Float.
	_types[&"math"] = FakeType.new(&"math", [FLOAT, FLOAT], [FLOAT], [])
	# Combine XYZ: three Floats -> Vec3.
	_types[&"combine_xyz"] = FakeType.new(&"combine_xyz", [FLOAT, FLOAT, FLOAT], [VEC3], [])


func run() -> void:
	_build_types()
	var resolver := Callable(self, "_resolver")

	# ----------------------------------------------------- Position and Output
	var g := NoiseGraph.new(resolver)
	check_eq(g.nodes.size(), 2, "a fresh graph holds exactly Position and Output")
	check_eq(g.position_id(), &"position_0", "the Position node's id is stable")
	check_eq(g.output_id(), &"output_0", "and so is the Output node's")
	check(g.node(g.position_id()) != null, "node() finds the Position")
	check_eq(g.node(g.position_id()).type_id, NoiseGraph.SOURCE_TYPE, "with the right type id")
	check(g.node(&"nothing_9") == null, "node() returns null for an unknown id")
	check(not g.remove_node(g.position_id()), "the Position cannot be removed")
	check(not g.remove_node(g.output_id()), "nor can the Output")
	check_eq(g.nodes.size(), 2, "and neither attempt changed anything")

	# ------------------------------------------------------------ add, remove
	var structural := [0]
	g.changed.connect(func() -> void: structural[0] += 1)
	var vn := g.add_node(&"value_noise", Vector2(40, 60))
	check_eq(vn, &"value_noise_0", "ids are '<type>_<n>' with the lowest free n")
	check_eq(structural[0], 1, "adding a node is a structural change")
	check_eq(g.node(vn).position, Vector2(40, 60), "the position is kept")
	check(g.node(vn).table != null, "the node got a table from its type")
	check(g.node(vn).table.has(&"scale"), "…with the type's parameters in it")
	check(g.node(vn).controls_open, "controls start open")
	check(g.node(vn).preview_open, "and so does the preview")

	var vn2 := g.add_node(&"value_noise", Vector2.ZERO)
	check_eq(vn2, &"value_noise_1", "a second node of the same type takes the next n")
	check(g.remove_node(vn2), "remove_node removes an ordinary node")
	check(g.node(vn2) == null, "…and it is gone")
	check_eq(g.add_node(&"value_noise", Vector2.ZERO), &"value_noise_1",
		"the freed number is reused")
	g.remove_node(&"value_noise_1")

	check_eq(g.add_node(&"no_such_type", Vector2.ZERO), &"",
		"an unknown type id is refused with an empty StringName")
	check_eq(g.add_node(NoiseGraph.SOURCE_TYPE, Vector2.ZERO), &"",
		"a second Position cannot be added")
	check_eq(g.add_node(NoiseGraph.OUTPUT_TYPE, Vector2.ZERO), &"",
		"nor a second Output")

	# ------------------------------------------------------------ can_connect
	var math := g.add_node(&"math", Vector2(120, 60))
	check(g.can_connect(vn, 0, math, 0),
		"value noise (Float) into Math.A (Float) is legal")
	check(not g.can_connect(g.position_id(), 0, math, 0),
		"Position (Vec3) into Math.A (Float) is refused: port types must match")
	check(not g.can_connect(&"missing_0", 0, math, 0), "an unknown `from` id is refused")
	check(not g.can_connect(vn, 0, &"missing_0", 0), "an unknown `to` id is refused")
	check(not g.can_connect(vn, 7, math, 0), "an out-of-range output port is refused")
	check(not g.can_connect(vn, 0, math, 9), "an out-of-range input port is refused")
	check(not g.can_connect(g.output_id(), 0, math, 0),
		"a node with no outputs cannot be a source of a link")

	check(g.connect_ports(vn, 0, math, 0), "connect_ports links them")
	check_eq(g.links.size(), 1, "and records one link")
	check(not g.connect_ports(vn, 0, math, 0), "the same link twice is refused")
	check(not g.can_connect(vn, 0, math, 0),
		"a second link into one input port is refused")
	check(g.can_connect(vn, 0, g.output_id(), 0),
		"but one output may feed many inputs")

	check_eq(g.input_link(math, 0), {"from": vn, "from_port": 0, "to": math, "to_port": 0},
		"input_link reports what feeds a port")
	check_eq(g.input_link(math, 1), {}, "and {} for an unconnected one")

	check(g.disconnect_ports(vn, 0, math, 0), "disconnect_ports unlinks")
	check_eq(g.links.size(), 0, "and the link is gone")
	check(not g.disconnect_ports(vn, 0, math, 0),
		"disconnecting a link that is not there is refused, not an error")

	# ----------------------------------------------------------------- cycles
	var t_a := g.add_node(&"transform", Vector2.ZERO)
	var t_b := g.add_node(&"transform", Vector2.ZERO)
	check(g.connect_ports(g.position_id(), 0, t_a, 0), "Position -> TransformA")
	check(not g.can_connect(t_a, 0, t_a, 0), "a node cannot feed itself")
	check(g.connect_ports(t_a, 0, t_b, 0), "TransformA -> TransformB")
	check(not g.can_connect(t_b, 0, t_a, 0), "a two-node cycle is refused")

	# ------------------------------------------------------------------ order
	g.connect_ports(vn, 0, math, 1)
	g.connect_ports(math, 0, g.output_id(), 0)
	var sorted := g.order()
	check_eq(sorted.size(), g.nodes.size(), "order() lists every node exactly once")
	var position := {}
	for i in sorted.size():
		position[sorted[i]] = i
	for link in g.links:
		check(position[link["from"]] < position[link["to"]],
			"order() is topological: %s before %s" % [link["from"], link["to"]])
	check_eq(g.order(), sorted, "order() is stable across calls")
	check_eq(NoiseGraph.new(resolver).order(), [&"output_0", &"position_0"],
		"ties break by id, deterministically")

	# --------------------------------------------------------- node_changed
	var touched: Array = []
	g.node_changed.connect(func(id: StringName, param: StringName) -> void: touched.append([id, param]))
	g.node(vn).table.set_value(&"scale", 0.75)
	check(touched.size() == 1 and touched[0][0] == vn and touched[0][1] == &"scale",
		"editing a node's table emits node_changed with the node AND param id")
	touched.clear()
	g.notify_node_changed(vn, &"tint_color")
	check_eq(touched, [[vn, &"tint_color"]], "notify_node_changed is the hook for an extras edit")
	var before_structural: int = structural[0]
	g.node(vn).table.set_value(&"seed", 0.9)
	check_eq(structural[0], before_structural, "a parameter edit is NOT structural")

	# -------------------------------------------------------------- JSON
	g.node(vn).controls_open = false
	g.node(vn).preview_open = false
	g.node(vn).position = Vector2(11, 22)
	g.node(math).extras["note"] = "kept"

	var d := g.to_dict()
	var warnings: Array = []
	var back := NoiseGraph.from_dict(d, warnings, resolver)
	check_eq(warnings.size(), 0, "a clean round trip warns about nothing")
	check_eq(back.nodes.size(), g.nodes.size(), "every node came back")
	check_eq(back.links.size(), g.links.size(), "every link came back")
	check_eq(back.node(vn).position, Vector2(11, 22), "positions round-trip")
	check(not back.node(vn).controls_open, "the controls flag round-trips")
	check(not back.node(vn).preview_open, "the preview flag round-trips")
	check_approx(float(back.node(vn).table.get_value(&"scale")), 0.75, "values round-trip")
	check_eq(back.node(math).extras.get("note", ""), "kept", "extras round-trip")
	check_eq(back.to_dict(), d, "and a second round trip is byte-identical")
	check(JSON.stringify(d) != "", "to_dict() is JSON-native")

	# --- an unknown type is skipped, with one warning, and drops its links ---
	var mangled := g.to_dict()
	var renamed := ""
	for entry in mangled["nodes"]:
		if String(entry["type"]) == "transform":
			entry["type"] = "from_a_newer_build"
			renamed = String(entry["id"])
			break
	check(renamed != "", "the test found a transform node to mangle")
	var skip_warnings: Array = []
	var partial := NoiseGraph.from_dict(mangled, skip_warnings, resolver)
	check_eq(partial.nodes.size(), g.nodes.size() - 1, "the unknown node was skipped")
	check_eq(skip_warnings.size(), 1, "with exactly one warning")
	check(String(skip_warnings[0]).contains("from_a_newer_build"),
		"and the warning names the type it did not know")
	for link in partial.links:
		check(String(link["from"]) != renamed and String(link["to"]) != renamed,
			"every link touching the skipped node was dropped")

	# ------------------------------------------------------------ the default
	var def := NoiseGraph.default_graph(resolver)
	check_eq(def.nodes.size(), 2, "default_graph is just Position and Output")
	check_eq(def.links.size(), 0, "with nothing wired, so the field is inert")
	check(def.node(def.position_id()) != null, "it has the Position")
	check(def.node(def.output_id()) != null, "and the Output")

	# ------------------------------------------------------------ duplicate
	g.connect_ports(g.position_id(), 0, vn, 0)
	var copy := g.duplicate_graph()
	check_eq(copy.nodes.size(), g.nodes.size(), "duplicate_graph copies every node")
	check_eq(copy.links.size(), g.links.size(), "and every link")
	copy.node(vn).table.set_value(&"scale", 0.125)
	check(absf(float(g.node(vn).table.get_value(&"scale")) - 0.125) > 1e-6,
		"the copy is DEEP: editing its table does not touch the original")
	copy.node(vn).extras["fresh"] = 1
	check(not g.node(vn).extras.has("fresh"), "extras are deep-copied too")

	# ------------------------------------------------------------ MAX_NODES
	var full := NoiseGraph.new(resolver)
	while full.nodes.size() < NoiseGraph.MAX_NODES:
		if full.add_node(&"transform", Vector2.ZERO) == &"":
			break
	check_eq(full.nodes.size(), NoiseGraph.MAX_NODES, "the graph fills to MAX_NODES")
	check_eq(full.add_node(&"transform", Vector2.ZERO), &"",
		"and refuses the next one with an empty StringName")

	# ------------------------------------------- no resolver: structure only
	var loose := NoiseGraph.new()
	check_eq(loose.nodes.size(), 2, "a graph with no resolver still has Position and Output")
	var loose_t := loose.add_node(&"transform", Vector2.ZERO)
	check(loose_t != &"", "it accepts any type id")
	check(loose.connect_ports(loose.position_id(), 0, loose_t, 0),
		"and skips port-type checks, so structure can be tested without a catalogue")
	check(not loose.can_connect(loose_t, 0, loose.position_id(), 0),
		"but a cycle is still a cycle without any types")
