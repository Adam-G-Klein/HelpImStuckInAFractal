extends NoiseNodeType
## Combine XYZ: builds a Vec3 from three Floats. The companion to Split XYZ, and
## the usual way to feed scalar noises into a Warp's direction input.


func _init() -> void:
	id = &"combine_xyz"
	title = "Combine XYZ"
	group = "Vector"
	order = 32
	description = "Combine XYZ: packs three Float fields into one Vec3, one per axis. Use it to build a direction field for Warp out of three noises, or to assemble a position by hand."
	inputs = [
		port("X", NoisePort.Type.FLOAT, "X: the x component. Unwired it is 0.", 0.0),
		port("Y", NoisePort.Type.FLOAT, "Y: the y component. Unwired it is 0.", 0.0),
		port("Z", NoisePort.Type.FLOAT, "Z: the z component. Unwired it is 0.", 0.0),
	]
	outputs = [
		port("V", NoisePort.Type.VEC3, "V: the assembled vector (X, Y, Z)."),
	]


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return "vec3 %s = vec3(%s, %s, %s);\n" % [outputs[0], inputs[0], inputs[1], inputs[2]]
