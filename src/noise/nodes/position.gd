extends NoiseNodeType
## Position: the sample point in fractal coordinates. Fixed, one per graph — the
## Source every field starts from. See NoiseNodeType's class docstring for the
## emit() conventions this obeys.


func _init() -> void:
	id = &"position"
	title = "Position"
	group = "Source"
	order = 0
	description = "Position: the point the field is being evaluated at, in fractal coordinates — the same space the distance estimator uses. Wire it into a noise or a transform to make the field vary through space. There is exactly one per graph."
	outputs = [
		port("P", NoisePort.Type.VEC3,
			"P: the sample position. Feed it into a Noise node, or transform it first to move, scale or rotate the field."),
	]


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, _values: Dictionary) -> String:
	return "vec3 %s = p;\n" % outputs[0]
