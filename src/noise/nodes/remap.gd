extends NoiseNodeType
## Remap: linearly maps A from one range to another, optionally clamped. The usual
## way to turn a noise's [-1, 1] into the [0, 1] a displacement or tint wants.


func _init() -> void:
	id = &"remap"
	title = "Remap"
	group = "Math"
	order = 52
	description = "Remap: rescales A from [In min, In max] to [Out min, Out max]. Turn a signed noise's -1..1 into 0..1 for a tint, or into a small band around 0 for a gentle displacement. Clamp keeps the output inside the out range for values of A outside the in range."
	inputs = [
		port("A", NoisePort.Type.FLOAT, "A: the value to remap. Unwired it is 0.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: A remapped to the out range."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	var ranges := [
		["in_min", "In min", -1.0], ["in_max", "In max", 1.0],
		["out_min", "Out min", 0.0], ["out_max", "Out max", 1.0]]
	for r in ranges:
		out.append(NoiseParamSpec.make({
			"id": r[0], "label": r[1],
			"type": NoiseParamSpec.Type.FLOAT, "default": r[2],
			"min": -2.0, "max": 2.0, "step": 0.01, "hard_min": -1000.0, "hard_max": 1000.0,
			"tooltip": "%s of the remap." % r[1],
			"effects": "Sets the end of the range the value is mapped from or to; swap the min and max to invert."}))
	out.append(NoiseParamSpec.make({
		"id": "clamp", "label": "Clamp",
		"type": NoiseParamSpec.Type.BOOL, "default": true,
		"tooltip": "Keep the output inside [Out min, Out max]. Baked into the shader, so changing it recompiles.",
		"effects": "On, values of A past the in range are held at the nearest out end. Off, they extrapolate past it."}))
	return out


func emit(inputs: Array, outputs: Array, uniforms: Dictionary, values: Dictionary) -> String:
	var clamp_line := ""
	if bool(values["clamp"]):
		clamp_line = "\n\t%s = clamp(%s, min(%s, %s), max(%s, %s));" % [
			outputs[0], outputs[0], uniforms["out_min"], uniforms["out_max"],
			uniforms["out_min"], uniforms["out_max"]]
	return """float %s;
{
	float _t = ((%s) - %s) / max(%s - %s, 1e-6);
	%s = %s + _t * (%s - %s);%s
}
""" % [outputs[0], inputs[0], uniforms["in_min"], uniforms["in_max"], uniforms["in_min"],
		outputs[0], uniforms["out_min"], uniforms["out_max"], uniforms["out_min"], clamp_line]
