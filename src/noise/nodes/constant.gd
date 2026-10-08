extends NoiseNodeType
## Constant: a single Float value. Useful as a fixed input to Math, Mix or Warp,
## and as a FLOAT uniform you can tune live.


func _init() -> void:
	id = &"constant"
	title = "Constant"
	group = "Math"
	order = 50
	description = "Constant: one fixed Float. Wire it where you want a tunable number — a Mix factor, a Math operand, a threshold. Because it is a FLOAT it updates live, with no recompile."
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: the constant value."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "value", "label": "Value",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.5,
		"min": -1.0, "max": 1.0, "step": 0.01, "hard_min": -1000.0, "hard_max": 1000.0,
		"tooltip": "The number this node outputs.",
		"effects": "Whatever you set; the slider covers -1..1 but you can type further."}))
	return out


func emit(_inputs: Array, outputs: Array, uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = %s;\n" % [outputs[0], uniforms["value"]]
