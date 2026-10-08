extends NoiseNodeType
## Gradient noise: 3D Perlin-style gradient noise over octaves (FBM). Output is in
## [-1, 1]. Smoother and more directional than Value noise. See NoiseNodeType for
## the emit() conventions.


func _init() -> void:
	id = &"gradient_noise"
	title = "Gradient noise"
	group = "Noise"
	order = 11
	description = "Gradient noise: smooth 3D Perlin-style noise from random gradients at each lattice point. More flowing and less blocky than Value noise. Octaves stack finer copies for detail. Output runs from -1 to 1."
	inputs = [
		port("P", NoisePort.Type.VEC3,
			"P: where to sample. Unwired it reads the sample position, so the noise fills space.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: the noise value, from -1 to 1."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "scale", "label": "Scale",
		"type": NoiseParamSpec.Type.FLOAT, "default": 1.0,
		"min": 0.05, "max": 8.0, "step": 0.01, "hard_min": 0.001, "hard_max": 64.0,
		"tooltip": "The noise frequency: higher packs more features into the same space.",
		"effects": "Larger makes finer, busier noise; smaller makes broad, slow swells."}))
	out.append(NoiseParamSpec.make({
		"id": "seed", "label": "Seed",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.0,
		"min": 0.0, "max": 100.0, "step": 0.1, "hard_min": -1000.0, "hard_max": 1000.0,
		"tooltip": "Shifts the random gradients without changing the noise's character.",
		"effects": "Any change gives a different but equally typical field."}))
	out.append(NoiseParamSpec.make({
		"id": "octaves", "label": "Octaves",
		"type": NoiseParamSpec.Type.INT, "default": 3,
		"min": 1, "max": 8, "hard_min": 1, "hard_max": 8,
		"tooltip": "How many layers of noise are stacked, each finer than the last. Baked into the shader, so changing it recompiles.",
		"effects": "1 is plain smooth noise. More octaves add fine detail and roughness, at a cost per octave."}))
	out.append(NoiseParamSpec.make({
		"id": "lacunarity", "label": "Lacunarity",
		"type": NoiseParamSpec.Type.FLOAT, "default": 2.0,
		"min": 1.0, "max": 4.0, "step": 0.01, "hard_min": 1.0, "hard_max": 8.0,
		"tooltip": "The frequency multiplier between octaves.",
		"effects": "2 doubles the detail frequency each octave (the usual choice). Higher spreads the scales further apart."}))
	out.append(NoiseParamSpec.make({
		"id": "gain", "label": "Gain",
		"type": NoiseParamSpec.Type.FLOAT, "default": 0.5,
		"min": 0.0, "max": 1.0, "step": 0.01, "hard_min": 0.0, "hard_max": 1.0,
		"tooltip": "How much each finer octave contributes relative to the one before.",
		"effects": "0.5 halves each octave's weight (smooth). Near 1 makes the fine detail as strong as the broad shape (rough, turbulent)."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, values: Dictionary) -> String:
	return """float %s = 0.0;
{
	vec3 _p = (%s) * %s;
	float _amp = 1.0;
	float _sum = 0.0;
	float _tot = 0.0;
	for (int _o = 0; _o < %d; _o++) {
		_sum += _amp * nz_perlin3(_p, %s + float(_o) * 13.0);
		_tot += _amp;
		_p *= %s;
		_amp *= %s;
	}
	%s = _sum / max(_tot, 1e-6);
}
""" % [outputs[0], inputs[0], uniforms["scale"], int(values["octaves"]),
		uniforms["seed"], uniforms["lacunarity"], uniforms["gain"], outputs[0]]
