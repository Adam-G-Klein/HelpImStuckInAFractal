extends NoiseNodeType
## Length: the magnitude of a Vec3 — length(V). A radial field when fed the sample
## position: 0 at the origin, growing outward.


func _init() -> void:
	id = &"length"
	title = "Length"
	group = "Math"
	order = 55
	description = "Length: the magnitude of a Vec3, length(V). Unwired it reads the sample position, giving a radial distance from the origin — remap it for a spherical falloff that fades the field with distance."
	inputs = [
		port("V", NoisePort.Type.VEC3,
			"V: the vector to measure. Unwired it reads the sample position.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: length(V), always >= 0."),
	]


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = length(%s);\n" % [outputs[0], inputs[0]]
