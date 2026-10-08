class_name NoiseNodeType
extends RefCounted
## One kind of noise-field graph node: its ports, its parameter rows, and the
## GLSL it emits. Subclass it, set the fields in `_init()`, override `emit()`,
## and drop the script in src/noise/nodes — NoiseNodeRegistry scans that
## directory, so there is no shared list to edit.
##
## A node script has no `class_name`: the registry loads it by path.
##
## Unlike Fractacular's IsolationNodeType there are no render passes and no
## shaders: a noise node is a fragment of GLSL spliced into one generated
## function. The conventions `emit()` obeys, and the compiler and tests rely on:
##
## - A FLOAT param is a live `uniform float n_<node_id>_<id>`; reach it in emit()
##   through the `uniforms` dictionary. An INT, BOOL or ENUM param is baked, so
##   read its concrete value from the `values` dictionary and write a literal
##   (an INT sets a loop bound, an ENUM picks an op). Editing a baked param
##   rebuilds the shader; editing a FLOAT only pushes its uniform.
## - emit() DECLARES each of its output locals (so it controls their GLSL type)
##   and assigns them. Keep temporaries inside a `{ }` block so two nodes never
##   collide on a helper name; only the declared outputs escape it.
## - An input expression is handed in ready to use: a wired FLOAT reads the
##   upstream local, an unwired one the port's own default constant; a wired
##   VEC3 reads the upstream local, an unwired one `p`.


## One port. `type` is a NoisePort.Type; `tooltip` is what the slot says, and it
## is not optional. `default` is the constant an unwired FLOAT input reads (it is
## ignored for a VEC3 input, which reads `p`, and for any output).
class PortSpec extends RefCounted:
	var name: String
	var type: int            # NoisePort.Type
	var tooltip: String
	var default: float = 0.0


var id: StringName             # e.g. &"value_noise"
var title: String
var description: String         # the node's own tooltip
var group: String = "Noise"    # add-menu grouping
var order: int = 100           # registry / menu sort key
var inputs: Array[PortSpec] = []
var outputs: Array[PortSpec] = []


static func port(name: String, type: int, tooltip: String, default := 0.0) -> PortSpec:
	var p := PortSpec.new()
	p.name = name
	p.type = type
	p.tooltip = tooltip
	p.default = default
	return p


## A four-float Array (what extras hold, because extras are JSON-native) as a
## Color. Short arrays are padded: a three-float array is opaque.
static func to_color(value: Variant) -> Color:
	if value is Color:
		return value
	if not (value is Array):
		return Color.WHITE
	var a: Array = value
	return Color(
		float(a[0]) if a.size() > 0 else 0.0,
		float(a[1]) if a.size() > 1 else 0.0,
		float(a[2]) if a.size() > 2 else 0.0,
		float(a[3]) if a.size() > 3 else 1.0)


static func from_color(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


## Virtual. The node's parameter rows, every one with a tooltip and an effects
## line. A row's id is also its shader-uniform suffix.
func params() -> Array[NoiseParamSpec]:
	return []


## Virtual. State that is not a parameter row, e.g. a colour. JSON-native values
## only — no Color, no Vector3, no Object: extras go straight into the saved
## graph. Use from_color() for a colour.
func extras_default() -> Dictionary:
	return {}


## Virtual. Build extra controls inside the node's GraphNode, under its rows
## (Output's tint-colour picker). A control writes `state.extras` and then calls
## the container's `notify_node_changed` meta Callable with (state.id, param_id).
func build_extra_controls(_state, _container: Control) -> void:
	pass


## Virtual. The GLSL for this node's outputs.
##   inputs:   Array[String], one GLSL expression per input port.
##   outputs:  Array[String], one GLSL variable name per output port to declare.
##   uniforms: {param id (String): uniform name} for FLOAT params.
##   values:   {param id (String): concrete value} for every param (baked reads).
## Returns the statements, declaring each output local.
func emit(_inputs: Array, _outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return ""


func new_table() -> NoiseParamTable:
	return NoiseParamTable.new(params())
