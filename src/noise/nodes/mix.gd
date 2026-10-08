extends NoiseNodeType
## Mix: linear blend between A and B by T — mix(A, B, T).


func _init() -> void:
	id = &"mix"
	title = "Mix"
	group = "Math"
	order = 54
	description = "Mix: blends A and B by T, mix(A, B, T) — T = 0 is all A, 1 is all B. Drive T with a noise or a mask to crossfade between two fields across space."
	inputs = [
		port("A", NoisePort.Type.FLOAT, "A: the value at T = 0. Unwired it is 0.", 0.0),
		port("B", NoisePort.Type.FLOAT, "B: the value at T = 1. Unwired it is 0.", 0.0),
		port("T", NoisePort.Type.FLOAT, "T: the blend factor, usually 0..1. Unwired it is 0, so the output is A.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: mix(A, B, T)."),
	]


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = mix(%s, %s, %s);\n" % [outputs[0], inputs[0], inputs[1], inputs[2]]
