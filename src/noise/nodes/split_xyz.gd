extends NoiseNodeType
## Split XYZ: pulls the three components out of a Vec3 as Floats. The companion to
## Combine XYZ; use it to drive separate maths off the sample position's axes.


func _init() -> void:
	id = &"split_xyz"
	title = "Split XYZ"
	group = "Vector"
	order = 33
	description = "Split XYZ: breaks a Vec3 into its three Float components. Unwired it reads the sample position, so its outputs are the x, y and z of where the field is being evaluated."
	inputs = [
		port("V", NoisePort.Type.VEC3,
			"V: the vector to split. Unwired it reads the sample position.", 0.0),
	]
	outputs = [
		port("X", NoisePort.Type.FLOAT, "X: the x component."),
		port("Y", NoisePort.Type.FLOAT, "Y: the y component."),
		port("Z", NoisePort.Type.FLOAT, "Z: the z component."),
	]


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = (%s).x;\nfloat %s = (%s).y;\nfloat %s = (%s).z;\n" % [
		outputs[0], inputs[0], outputs[1], inputs[0], outputs[2], inputs[0]]
