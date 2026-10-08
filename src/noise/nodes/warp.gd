extends NoiseNodeType
## Warp: domain warping. Pushes the sample position along a direction field —
## P + Amount × D — so whatever reads the warped position is smeared and curled
## along D. Feed a noise (via Combine XYZ, or a vector noise) into D.


func _init() -> void:
	id = &"warp"
	title = "Warp"
	group = "Vector"
	order = 31
	description = "Warp (domain warp): offsets the sample position by Amount times a direction field, P + Amount × D. Reading a noise at the warped position bends and curls it along D — the classic way to turn bland noise into flowing, marbled structure. D is often a second noise."
	inputs = [
		port("P", NoisePort.Type.VEC3,
			"P: the position to warp. Unwired it reads the sample position.", 0.0),
		port("D", NoisePort.Type.VEC3,
			"D: the direction field to push along. Unwired it reads the sample position, which rarely does anything useful — feed it a noise.", 0.0),
	]
	outputs = [
		port("P", NoisePort.Type.VEC3, "P: the warped position, P + Amount × D."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "amount", "label": "Amount",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.5,
		"min": -5.0, "max": 5.0, "step": 0.01, "hard_min": -100.0, "hard_max": 100.0,
		"tooltip": "How far the position is pushed along D.",
		"effects": "0 passes P straight through. Small values gently bend the field; large values smear it into long streaks. Negative reverses the push."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, _values: Dictionary) -> String:
	return "vec3 %s = (%s) + %s * (%s);\n" % [outputs[0], inputs[0], uniforms["amount"], inputs[1]]
