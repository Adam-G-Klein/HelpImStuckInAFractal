class_name Binding
extends RefCounted
## How one bindable attribute is driven on top of its default:
##   value = default + gain * wave(raw)
## where raw is a virtual axis's value or the clock. Ported from Fractacular's
## Binding, with the source changed from an enum to a StringName: `&""` is none,
## `&"time"` the clock, anything else an axis id.

enum Waveform { LINEAR, SINE, TRIANGLE }

var source: StringName = &""
var gain: float = 1.0
var waveform: Waveform = Waveform.LINEAR
## Source units per cycle for SINE and TRIANGLE. Ignored for LINEAR.
var period: float = 4.0


func is_active() -> bool:
	return source != &""


func duplicate() -> Binding:
	var b := Binding.new()
	b.source = source
	b.gain = gain
	b.waveform = waveform
	b.period = period
	return b


func to_dict() -> Dictionary:
	return {
		"source": String(source),
		"gain": gain,
		"waveform": Waveform.keys()[waveform],
		"period": period,
	}


static func from_dict(d: Dictionary) -> Binding:
	var b := Binding.new()
	b.source = StringName(str(d.get("source", "")))
	b.gain = float(d.get("gain", 1.0))
	var wi := Waveform.keys().find(str(d.get("waveform", "LINEAR")))
	b.waveform = (wi if wi >= 0 else Waveform.LINEAR) as Waveform
	b.period = maxf(float(d.get("period", 4.0)), 1e-6)
	return b
