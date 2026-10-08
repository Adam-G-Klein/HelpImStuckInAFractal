extends NoiseNodeType
## Math: one of a dozen operations on two Floats (some use only A). The workhorse
## for shaping a noise — Abs folds it into ridges, Multiply gates it, Power sets
## its contrast.


func _init() -> void:
	id = &"math"
	title = "Math"
	group = "Math"
	order = 51
	description = "Math: combine A and B with a chosen operation. Add/Subtract/Multiply/Divide/Min/Max/Power use both; Abs, Sin, Cos, Floor and Fract use only A. Abs of a signed noise makes ridges; Power sharpens or softens; Multiply by a mask carves the field to a region."
	inputs = [
		port("A", NoisePort.Type.FLOAT, "A: the first operand. Unwired it is 0.", 0.0),
		port("B", NoisePort.Type.FLOAT, "B: the second operand (ignored by the one-input ops). Unwired it is 0.", 0.0),
	]
	outputs = [
		port("Float", NoisePort.Type.FLOAT, "Float: the result of A op B."),
	]


func params() -> Array[NoiseParamSpec]:
	var out: Array[NoiseParamSpec] = []
	out.append(NoiseParamSpec.make({
		"id": "op", "label": "Op",
		"type": NoiseParamSpec.Type.ENUM, "default": 0,
		"enum_labels": ["Add", "Subtract", "Multiply", "Divide", "Min", "Max",
			"Power", "Abs(A)", "Sin(A)", "Cos(A)", "Floor(A)", "Fract(A)"],
		"tooltip": "The operation. Baked into the shader, so changing it recompiles.",
		"effects": "Add/Subtract shift and layer; Multiply and Min gate; Max unions; Power (abs(A)^B) sets contrast; Abs(A) folds a signed field into ridges; Sin/Cos band it; Floor/Fract terrace it."}))
	return out


func emit(inputs: Array, outputs: Array, _uniforms: Dictionary, values: Dictionary) -> String:
	var a: String = "(%s)" % inputs[0]
	var b: String = "(%s)" % inputs[1]
	var expr := ""
	match int(values["op"]):
		0: expr = "%s + %s" % [a, b]
		1: expr = "%s - %s" % [a, b]
		2: expr = "%s * %s" % [a, b]
		3: expr = "(%s != 0.0 ? %s / %s : 0.0)" % [b, a, b]
		4: expr = "min(%s, %s)" % [a, b]
		5: expr = "max(%s, %s)" % [a, b]
		6: expr = "pow(abs(%s), %s)" % [a, b]
		7: expr = "abs(%s)" % a
		8: expr = "sin(%s)" % a
		9: expr = "cos(%s)" % a
		10: expr = "floor(%s)" % a
		11: expr = "fract(%s)" % a
		_: expr = a
	return "float %s = %s;\n" % [outputs[0], expr]
