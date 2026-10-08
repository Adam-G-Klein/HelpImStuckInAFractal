class_name NoiseGraph
extends RefCounted
## The model behind a noise-field editor: which nodes exist, what feeds what, and
## every node's parameters. RefCounted, headless, serialisable, and the only
## thing the editor, the compiler and the workspace all agree about.
##
## A port of Fractacular's IsolationGraph. Its fixed Source becomes a Position
## node and its Output stays an Output; both are one-per-graph and cannot be
## added or removed. It knows nothing about node types beyond what it reads off
## whatever `resolve_type` hands back: `id`, `inputs`, `outputs` (Arrays of things
## with a `.type: int`) and `new_table()`. The editor passes
## NoiseNodeRegistry.type_by_id; tests inject a fake.
##
## `node_changed` carries the param id as well as the node id, so a listener can
## tell a live FLOAT edit (push a uniform) from a baked INT/BOOL/ENUM edit
## (rebuild the shader) without a second lookup.

signal changed                                          # anything structural
signal node_changed(id: StringName, param_id: StringName)  # a node's table or extras

const SOURCE_TYPE := &"position"
const OUTPUT_TYPE := &"output"
const MAX_NODES := 64


class NodeState extends RefCounted:
	var id: StringName
	var type_id: StringName
	var position: Vector2
	var table: NoiseParamTable
	var extras: Dictionary
	var controls_open: bool = true
	var preview_open: bool = true


## id -> NodeState. Read it; edit through the methods.
var nodes: Dictionary = {}
## [{from: StringName, from_port: int, to: StringName, to_port: int}]
var links: Array = []
## (StringName) -> node type or null.
var resolve_type: Callable


func _init(type_resolver := Callable()) -> void:
	resolve_type = type_resolver
	_insert(SOURCE_TYPE, Vector2(40, 40))
	_insert(OUTPUT_TYPE, Vector2(560, 40))


func node(id: StringName) -> NodeState:
	return nodes.get(id)


func position_id() -> StringName:
	return &"position_0"


func output_id() -> StringName:
	return &"output_0"


func _next_id(type_id: StringName) -> StringName:
	var n := 0
	while true:
		var candidate := StringName("%s_%d" % [type_id, n])
		if not nodes.has(candidate):
			return candidate
		n += 1
	return &""  # unreachable


func _resolve(type_id: StringName) -> Variant:
	if not resolve_type.is_valid():
		return null
	return resolve_type.call(type_id)


func _insert(type_id: StringName, position: Vector2) -> StringName:
	var id := _next_id(type_id)
	var type: Variant = _resolve(type_id)
	var state := NodeState.new()
	state.id = id
	state.type_id = type_id
	state.position = position
	if type != null:
		state.table = type.new_table()
	else:
		state.table = NoiseParamTable.new()
	if type != null and type.has_method(&"extras_default"):
		state.extras = type.extras_default().duplicate(true)
	else:
		state.extras = {}
	# Weak-ref the graph and close over the id VALUE, not the NodeState object,
	# so the table's listen is one-way and never an ownership cycle.
	var self_weak: WeakRef = weakref(self)
	state.table.changed.connect(func(attr_id: StringName) -> void:
		var g: NoiseGraph = self_weak.get_ref()
		if g != null:
			g.node_changed.emit(id, attr_id))
	nodes[id] = state
	return id


func add_node(type_id: StringName, position: Vector2) -> StringName:
	if nodes.size() >= MAX_NODES:
		return &""
	if type_id == SOURCE_TYPE or type_id == OUTPUT_TYPE:
		return &""
	if resolve_type.is_valid() and _resolve(type_id) == null:
		return &""
	var id := _insert(type_id, position)
	changed.emit()
	return id


## Removes an ordinary node and every link touching it, then emits `changed`.
func remove_node(id: StringName) -> bool:
	if id == position_id() or id == output_id():
		return false
	if not nodes.has(id):
		return false
	var kept: Array = []
	for link in links:
		if link["from"] != id and link["to"] != id:
			kept.append(link)
	links = kept
	nodes.erase(id)
	changed.emit()
	return true


func _port_type(id: StringName, port: int, is_input: bool) -> int:
	if not resolve_type.is_valid():
		return -1
	var state: NodeState = nodes.get(id)
	if state == null:
		return -1
	var type: Variant = _resolve(state.type_id)
	if type == null:
		return -1
	var ports: Array = type.inputs if is_input else type.outputs
	if port < 0 or port >= ports.size():
		return -1
	return ports[port].type


func _reaches(from: StringName, target: StringName) -> bool:
	var visited: Dictionary = {}
	var queue: Array = [from]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == target:
			return true
		if visited.has(current):
			continue
		visited[current] = true
		for link in links:
			if link["from"] == current:
				queue.append(link["to"])
	return false


func can_connect(from: StringName, from_port: int, to: StringName, to_port: int) -> bool:
	if not nodes.has(from) or not nodes.has(to):
		return false
	if from == to:
		return false
	var from_state: NodeState = nodes[from]
	var to_state: NodeState = nodes[to]

	if resolve_type.is_valid():
		var from_type: Variant = _resolve(from_state.type_id)
		var to_type: Variant = _resolve(to_state.type_id)
		if from_type == null or to_type == null:
			return false
		if from_port < 0 or from_port >= from_type.outputs.size():
			return false
		if to_port < 0 or to_port >= to_type.inputs.size():
			return false

	var from_type_id := _port_type(from, from_port, false)
	var to_type_id := _port_type(to, to_port, true)
	if from_type_id != -1 and to_type_id != -1 and from_type_id != to_type_id:
		return false

	for link in links:
		if link["to"] == to and link["to_port"] == to_port:
			return false

	if _reaches(to, from):
		return false

	return true


func connect_ports(from: StringName, from_port: int, to: StringName, to_port: int) -> bool:
	if not can_connect(from, from_port, to, to_port):
		return false
	links.append({"from": from, "from_port": from_port, "to": to, "to_port": to_port})
	changed.emit()
	return true


func disconnect_ports(from: StringName, from_port: int, to: StringName, to_port: int) -> bool:
	for i in links.size():
		var link: Dictionary = links[i]
		if link["from"] == from and link["from_port"] == from_port \
				and link["to"] == to and link["to_port"] == to_port:
			links.remove_at(i)
			changed.emit()
			return true
	return false


func input_link(to: StringName, to_port: int) -> Dictionary:
	for link in links:
		if link["to"] == to and link["to_port"] == to_port:
			return link
	return {}


## StringName's default `<` is interning-order dependent, so compare through
## String() for a stable, id-lexicographic tie break.
static func _by_id(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


func order() -> Array:
	var in_degree: Dictionary = {}
	for id in nodes:
		in_degree[id] = 0
	for link in links:
		if in_degree.has(link["to"]):
			in_degree[link["to"]] = in_degree[link["to"]] + 1

	var ready: Array = []
	for id in in_degree:
		if in_degree[id] == 0:
			ready.append(id)
	ready.sort_custom(_by_id)

	var result: Array = []
	while not ready.is_empty():
		var current: StringName = ready.pop_front()
		result.append(current)
		var newly_ready: Array = []
		for link in links:
			if link["from"] == current:
				var to_id: StringName = link["to"]
				if in_degree.has(to_id):
					in_degree[to_id] = in_degree[to_id] - 1
					if in_degree[to_id] == 0:
						newly_ready.append(to_id)
		if not newly_ready.is_empty():
			newly_ready.sort_custom(_by_id)
			ready.append_array(newly_ready)
			ready.sort_custom(_by_id)

	if result.size() < nodes.size():
		var remaining: Array = []
		for id in nodes:
			if not result.has(id):
				remaining.append(id)
		remaining.sort_custom(_by_id)
		result.append_array(remaining)

	return result


func notify_node_changed(id: StringName, param_id := &"") -> void:
	node_changed.emit(id, param_id)


func duplicate_graph() -> NoiseGraph:
	var copy := NoiseGraph.new()
	copy.resolve_type = resolve_type
	copy.nodes = {}
	for id in nodes:
		var state: NodeState = nodes[id]
		var new_state := NodeState.new()
		new_state.id = state.id
		new_state.type_id = state.type_id
		new_state.position = state.position
		new_state.table = state.table.duplicate()
		new_state.extras = state.extras.duplicate(true)
		new_state.controls_open = state.controls_open
		new_state.preview_open = state.preview_open
		var copy_weak: WeakRef = weakref(copy)
		var new_id: StringName = id
		new_state.table.changed.connect(func(attr_id: StringName) -> void:
			var g: NoiseGraph = copy_weak.get_ref()
			if g != null:
				g.node_changed.emit(new_id, attr_id))
		copy.nodes[id] = new_state
	copy.links = links.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	var node_ids: Array = nodes.keys()
	node_ids.sort_custom(_by_id)
	var node_list: Array = []
	for id in node_ids:
		var state: NodeState = nodes[id]
		node_list.append({
			"id": String(state.id),
			"type": String(state.type_id),
			"position": [state.position.x, state.position.y],
			"params": state.table.to_dict(),
			"extras": state.extras.duplicate(true),
			"controls_open": state.controls_open,
			"preview_open": state.preview_open,
		})

	var link_list: Array = links.duplicate(true)
	link_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := [String(a["from"]), a["from_port"], String(a["to"]), a["to_port"]]
		var kb := [String(b["from"]), b["from_port"], String(b["to"]), b["to_port"]]
		return ka < kb)
	var link_dicts: Array = []
	for link in link_list:
		link_dicts.append({
			"from": String(link["from"]),
			"from_port": link["from_port"],
			"to": String(link["to"]),
			"to_port": link["to_port"],
		})

	return {"nodes": node_list, "links": link_dicts}


static func from_dict(d: Dictionary, warnings: Array, type_resolver := Callable()) -> NoiseGraph:
	var g := NoiseGraph.new(type_resolver)

	for entry in d.get("nodes", []):
		var type_id := StringName(entry.get("type", ""))
		var id := StringName(entry.get("id", ""))

		var state: NodeState
		if type_id == SOURCE_TYPE:
			state = g.node(g.position_id())
		elif type_id == OUTPUT_TYPE:
			state = g.node(g.output_id())
		else:
			if type_resolver.is_valid() and type_resolver.call(type_id) == null:
				warnings.append("Unknown noise node type '%s' skipped" % type_id)
				continue
			var new_id := g._insert(type_id, Vector2.ZERO)
			state = g.nodes[new_id]
			if new_id != id:
				g.nodes.erase(new_id)
				state.id = id
				g.nodes[id] = state

		var pos: Array = entry.get("position", [0.0, 0.0])
		state.position = Vector2(float(pos[0]), float(pos[1]))
		var table_warnings: Array[String] = state.table.apply_dict(entry.get("params", {}))
		for w in table_warnings:
			warnings.append("%s: %s" % [id, w])
		state.extras = entry.get("extras", {}).duplicate(true)
		state.controls_open = bool(entry.get("controls_open", true))
		state.preview_open = bool(entry.get("preview_open", true))

	for link_entry in d.get("links", []):
		var from_id := StringName(link_entry.get("from", ""))
		var to_id := StringName(link_entry.get("to", ""))
		var from_port := int(link_entry.get("from_port", 0))
		var to_port := int(link_entry.get("to_port", 0))
		if not g.nodes.has(from_id) or not g.nodes.has(to_id):
			continue
		if not g.can_connect(from_id, from_port, to_id, to_port):
			continue
		g.links.append({"from": from_id, "from_port": from_port, "to": to_id, "to_port": to_port})

	return g


## The default graph: a Position and an Output, nothing wired, so the field is
## inert and the fractal renders exactly as it would with no editor at all.
static func default_graph(type_resolver := Callable()) -> NoiseGraph:
	return NoiseGraph.new(type_resolver)
