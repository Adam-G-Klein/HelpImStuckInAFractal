extends "res://tests/test_case.gd"
## BindingResolver math: axis and time sources, a missing axis, waveforms,
## wrap vs clamp, INT rounding, and inactive / non-bindable yielding defaults.


func _spec(id: String, type: AttributeSpec.Type, default: Variant, lo: float, hi: float, extra: Dictionary = {}) -> AttributeSpec:
	var d := {"id": id, "label": id, "type": type, "default": default,
		"min": lo, "max": hi, "tooltip": "t", "effects": "e"}
	d.merge(extra, true)
	return AttributeSpec.make(d)


func _bind(source: StringName, gain: float = 1.0, wave: Binding.Waveform = Binding.Waveform.LINEAR, period: float = 4.0) -> Binding:
	var b := Binding.new()
	b.source = source
	b.gain = gain
	b.waveform = wave
	b.period = period
	return b


func run() -> void:
	var F := AttributeSpec.Type.FLOAT
	var a := _spec("a", F, 1.0, -100.0, 100.0)
	var ang := _spec("ang", F, 350.0, 0.0, 360.0, {"wrap": true})
	var n := _spec("n", AttributeSpec.Type.INT, 10, 1, 100)
	var en := AttributeSpec.make({"id": "e", "label": "E", "type": AttributeSpec.Type.ENUM,
		"default": 1, "enum_labels": ["A", "B"], "tooltip": "t", "effects": "e"})
	var table := AttributeTable.new([a, ang, n, en])

	# --- inactive yields defaults ---
	var v := BindingResolver.resolve(table, {&"a": 1.0}, 9.0)
	check_eq(v[&"a"], 1.0, "unbound float is its default")
	check_eq(v[&"n"], 10, "unbound int is its default")
	check_eq(v[&"e"], 1, "a non-bindable enum is its default")
	check_eq(v, BindingResolver.resolve_defaults(table), "resolve with no bindings equals resolve_defaults")

	# --- time source, LINEAR ---
	table.set_binding(&"a", _bind(&"time", 1.0))
	check_approx(BindingResolver.resolve(table, {}, 7.25)[&"a"], 8.25, "time: default + gain * t")

	# --- an axis source ---
	table.set_binding(&"a", _bind(&"q", 2.0))
	check_approx(BindingResolver.resolve(table, {&"q": 1.5}, 0.0)[&"a"], 4.0, "axis: default + gain * value")
	table.set_binding(&"a", _bind(&"q", -1.0))
	check_approx(BindingResolver.resolve(table, {&"q": 0.5}, 0.0)[&"a"], 0.5, "axis with negative gain")

	# --- a missing axis id yields raw 0 -> the default ---
	table.set_binding(&"a", _bind(&"gone", 1000.0))
	check_approx(BindingResolver.resolve(table, {&"q": 1.0}, 0.0)[&"a"], 1.0, "a missing axis resolves to the default")

	# --- waveforms ---
	check_approx(BindingResolver.waveform_value(3.0, Binding.Waveform.LINEAR, 4.0), 3.0, "LINEAR passes raw")
	check_approx(BindingResolver.waveform_value(1.0, Binding.Waveform.SINE, 4.0), 1.0, "SINE peaks at period/4")
	check_approx(BindingResolver.waveform_value(2.0, Binding.Waveform.SINE, 4.0), 0.0, "SINE zero at period/2")
	check_approx(BindingResolver.waveform_value(0.0, Binding.Waveform.TRIANGLE, 4.0), 0.0, "TRIANGLE starts at 0")
	check_approx(BindingResolver.waveform_value(1.0, Binding.Waveform.TRIANGLE, 4.0), 1.0, "TRIANGLE peaks at period/4")
	check_approx(BindingResolver.waveform_value(2.0, Binding.Waveform.TRIANGLE, 4.0), 0.0, "TRIANGLE zero at period/2")
	check_approx(BindingResolver.waveform_value(3.0, Binding.Waveform.TRIANGLE, 4.0), -1.0, "TRIANGLE trough at 3/4 period")
	check_approx(BindingResolver.waveform_value(-1.0, Binding.Waveform.TRIANGLE, 4.0), -1.0, "TRIANGLE handles negative raw")
	table.set_binding(&"a", _bind(&"time", 3.0, Binding.Waveform.SINE, 2.0))
	check_approx(BindingResolver.resolve(table, {}, 0.5)[&"a"], 4.0, "SINE with gain and period through resolve")

	# --- wrap vs clamp applied by sanitize ---
	table.set_binding(&"a", _bind(&"q", 1000.0))
	check_approx(BindingResolver.resolve(table, {&"q": 1.0}, 0.0)[&"a"], 100.0, "clamped to hard_max")
	table.set_binding(&"ang", _bind(&"q", 20.0))
	check_approx(BindingResolver.resolve(table, {&"q": 1.0}, 0.0)[&"ang"], 10.0, "wrapped into [min, max): 350+20 -> 10")

	# --- INT rounds ---
	table.set_binding(&"n", _bind(&"q", 1.0))
	check_eq(BindingResolver.resolve(table, {&"q": 2.6}, 0.0)[&"n"], 13, "INT rounds the driven value (10+2.6 -> 13)")
