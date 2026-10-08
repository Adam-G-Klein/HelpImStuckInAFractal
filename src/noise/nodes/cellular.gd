extends NoiseNodeType
## Cellular: Worley F1 noise — the distance to the nearest of one random feature
## point per lattice cell. Gives organic cell / Voronoi patterns. Output is a
## distance, roughly 0 at a feature point up to ~1 between them.


func _init() -> void:
	id = &"cellular"
	title = "Cellular"
	group = "Noise"
	order = 12
	description = "Cellular (Worley F1): the distance to the nearest random feature point, one per cell. Near 0 at a feature point and larger between them, it draws organic cells and cracks. Remap it to turn the cell walls into ridges."
	inputs = [
		port("P", NoisePort.Type.VEC3,
			"P: where to sample. Unwired it reads the sample position, so the cells fill space.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: the F1 distance, ~0 at a feature point up to ~1 between them."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "scale", "label": "Scale",
		"type": NoiseParamSpec.Type.FLOAT, "default": 1.0,
		"min": 0.05, "max": 8.0, "step": 0.01, "hard_min": 0.001, "hard_max": 64.0,
		"tooltip": "The cell frequency: higher makes smaller, more numerous cells.",
		"effects": "Small values give a few big cells; large values a dense field of small ones."}))
	out.append(NoiseParamSpec.make({
		"id": "seed", "label": "Seed",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.0,
		"min": 0.0, "max": 100.0, "step": 0.1, "hard_min": -1000.0, "hard_max": 1000.0,
		"tooltip": "Shifts the feature points without changing the pattern's character.",
		"effects": "Any change rearranges the cells."}))
	out.append(NoiseParamSpec.make({
		"id": "jitter", "label": "Jitter",
		"type": NoiseParamSpec.Type.FLOAT, "default": 1.0,
		"min": 0.0, "max": 1.0, "step": 0.01, "hard_min": 0.0, "hard_max": 1.0,
		"tooltip": "How far each feature point is randomly offset within its cell.",
		"effects": "0 pins points to a regular grid (square cells); 1 is fully random (irregular, organic cells)."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, _values: Dictionary) -> String:
	return "float %s = nz_worley3((%s) * %s, %s, %s);\n" % [
		outputs[0], inputs[0], uniforms["scale"], uniforms["seed"], uniforms["jitter"]]
