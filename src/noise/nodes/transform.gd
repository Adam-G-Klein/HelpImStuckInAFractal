extends NoiseNodeType
## Transform: move, scale and rotate a vector field. Rotate about an axis, then
## scale uniformly, then offset. Use it on the sample position before a Noise node
## to place and orient the noise.


func _init() -> void:
	id = &"transform"
	title = "Transform"
	group = "Vector"
	order = 30
	description = "Transform: rotates a vector field about X, Y or Z, scales it uniformly, then offsets it. Put it before a Noise node to move, zoom and turn the noise in space. Scaling the position is the opposite of scaling the noise: a larger Scale here spreads the features out."
	inputs = [
		port("P", NoisePort.Type.VEC3,
			"P: the field to transform. Unwired it reads the sample position.", 0.0),
	]
	outputs = [
		port("P", NoisePort.Type.VEC3, "P: the transformed field."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	for axis in ["x", "y", "z"]:
		out.append(NoiseParamSpec.make({
			"id": "offset_" + axis, "label": "Offset " + axis.to_upper(),
			"type": NoiseParamSpec.Type.FLOAT, "default": 0.0,
			"min": -10.0, "max": 10.0, "step": 0.01, "hard_min": -1000.0, "hard_max": 1000.0,
			"tooltip": "Shifts the field along %s after rotation and scaling." % axis.to_upper(),
			"effects": "Slides the pattern; combined with a Warp it animates by hand."}))
	out.append(NoiseParamSpec.make({
		"id": "scale", "label": "Scale",
		"type": NoiseParamSpec.Type.FLOAT, "default": 1.0,
		"min": 0.1, "max": 10.0, "step": 0.01, "hard_min": 0.001, "hard_max": 1000.0,
		"tooltip": "Uniform multiplier on the field before the offset.",
		"effects": "Larger spreads features apart (the noise looks zoomed out); smaller packs them together."}))
	out.append(NoiseParamSpec.make({
		"id": "axis", "label": "Axis",
		"type": NoiseParamSpec.Type.ENUM, "default": 2,
		"enum_labels": ["X", "Y", "Z"],
		"tooltip": "Which axis the rotation turns around. Baked into the shader, so changing it recompiles.",
		"effects": "Pick the axis the pattern should spin about; Angle sets how far."}))
	out.append(NoiseParamSpec.make({
		"id": "angle", "label": "Angle",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.0,
		"min": -180.0, "max": 180.0, "step": 1.0, "hard_min": -360.0, "hard_max": 360.0,
		"tooltip": "Rotation about the chosen axis, in degrees.",
		"effects": "Turns the whole field; useful to break up the grid alignment of value noise."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, values: Dictionary) -> String:
	var matrix := _rotation_matrix(int(values["axis"]))
	return """vec3 %s;
{
	vec3 _v = %s;
	float _a = radians(%s);
	float _c = cos(_a);
	float _s = sin(_a);
	mat3 _r = %s;
	_v = _r * _v;
	_v *= %s;
	_v += vec3(%s, %s, %s);
	%s = _v;
}
""" % [outputs[0], inputs[0], uniforms["angle"], matrix, uniforms["scale"],
		uniforms["offset_x"], uniforms["offset_y"], uniforms["offset_z"], outputs[0]]


## Column-major mat3 for a rotation about the chosen axis (0=X, 1=Y, 2=Z).
static func _rotation_matrix(axis: int) -> String:
	match axis:
		0:
			return "mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, _c, _s), vec3(0.0, -_s, _c))"
		1:
			return "mat3(vec3(_c, 0.0, -_s), vec3(0.0, 1.0, 0.0), vec3(_s, 0.0, _c))"
		_:
			return "mat3(vec3(_c, _s, 0.0), vec3(-_s, _c, 0.0), vec3(0.0, 0.0, 1.0))"
