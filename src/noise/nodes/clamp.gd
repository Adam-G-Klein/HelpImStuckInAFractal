extends NoiseNodeType
## Clamp: holds A between a Min and a Max.


func _init() -> void:
	id = &"clamp"
	title = "Clamp"
	group = "Math"
	order = 53
	description = "Clamp: limits A to the range [Min, Max], holding anything outside at the nearest end. Use it to cap a runaway field or to flatten the top and bottom of a noise into plateaus."
	inputs = [
		port("A", NoisePort.Type.FLOAT, "A: the value to clamp. Unwired it is 0.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: A held within [Min, Max]."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "min", "label": "Min",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.0,
		"min": -2.0, "max": 2.0, "step": 0.01, "hard_min": -1000.0, "hard_max": 1000.0,
		"tooltip": "The lowest value the output can take.",
		"effects": "Anything below it is raised to it, flattening the valleys."}))
	out.append(NoiseParamSpec.make({
		"id": "max", "label": "Max",
		"type": NoiseParamSpec.Type.FLOAT, "default": 1.0,
		"min": -2.0, "max": 2.0, "step": 0.01, "hard_min": -1000.0, "hard_max": 1000.0,
		"tooltip": "The highest value the output can take.",
		"effects": "Anything above it is lowered to it, flattening the peaks."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = clamp(%s, min(%s, %s), max(%s, %s));\n" % [
		outputs[0], inputs[0], uniforms["min"], uniforms["max"], uniforms["min"], uniforms["max"]]
