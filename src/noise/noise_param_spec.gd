class_name NoiseParamSpec
extends RefCounted
## Describes one knob of a noise node: its id (also its shader-uniform suffix),
## its type and range, and the plain-language tooltip and "what different values
## do" text every row shows.
##
## A port of Fractacular's AttributeSpec with its Category and its bindings
## dropped: a noise field has no movement point, so there is nothing to bind to.
##
## A FLOAT param becomes a live `uniform` the compiler can push without a
## recompile. An INT, BOOL or ENUM param is baked into the generated GLSL — it
## sets a loop bound or picks an op — so editing one rebuilds the shader.

enum Type { FLOAT, INT, BOOL, ENUM }

const REQUIRED_KEYS := ["id", "label", "type", "default", "tooltip", "effects"]

## Stable key; a FLOAT's shader uniform is `n_<node_id>_<id>`.
var id: StringName
var label: String
var type: Type
var default_value: Variant
## Slider range. Spin boxes may type past it up to the hard range.
var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.01
## Absolute limits for typed values. Default to min/max.
var hard_min: float = 0.0
var hard_max: float = 1.0
## Slider is logarithmic; the row shows real tick values in the tooltip.
var log_scale: bool = false
## Typed values wrap into [min, max) instead of clamping (angles).
var wrap: bool = false
## What this is, in plain language.
var tooltip: String = ""
## What different values do.
var effects: String = ""
var enum_labels: Array[String] = []
## Value stored for each label. Defaults to the label indices.
var enum_values: Array[int] = []
## Optional `Callable(values: Dictionary) -> bool`; false collapses the row.
var show_when: Callable = Callable()
## Optional `Callable(values: Dictionary) -> bool`; false disables the row.
var enabled_when: Callable = Callable()


## Build a spec from a dictionary. Keys: the REQUIRED_KEYS plus optional `min`,
## `max`, `step`, `hard_min`, `hard_max`, `log`, `wrap`, `enum_labels`,
## `enum_values`, `show_when`, `enabled_when`.
static func make(d: Dictionary) -> NoiseParamSpec:
	for key in REQUIRED_KEYS:
		if not d.has(key):
			push_error("NoiseParamSpec.make: missing '%s' in %s" % [key, d])
			return null
	var s := NoiseParamSpec.new()
	s.id = StringName(d["id"])
	s.label = String(d["label"])
	s.type = d["type"] as Type
	s.tooltip = String(d["tooltip"])
	s.effects = String(d["effects"])
	s.log_scale = bool(d.get("log", false))
	s.wrap = bool(d.get("wrap", false))
	match s.type:
		Type.FLOAT:
			s.min_value = float(d.get("min", 0.0))
			s.max_value = float(d.get("max", 1.0))
			s.step = float(d.get("step", 0.01))
			s.default_value = float(d["default"])
		Type.INT:
			s.min_value = float(d.get("min", 0))
			s.max_value = float(d.get("max", 1))
			s.step = 1.0
			s.default_value = int(d["default"])
		Type.BOOL:
			s.default_value = bool(d["default"])
		Type.ENUM:
			s.enum_labels.assign(d.get("enum_labels", []))
			if d.has("enum_values"):
				s.enum_values.assign(d["enum_values"])
			else:
				for i in s.enum_labels.size():
					s.enum_values.append(i)
			s.min_value = 0.0
			s.max_value = float(maxi(s.enum_labels.size() - 1, 0))
			s.step = 1.0
			s.default_value = int(d["default"])
	s.hard_min = float(d.get("hard_min", s.min_value))
	s.hard_max = float(d.get("hard_max", s.max_value))
	if d.has("show_when"):
		s.show_when = d["show_when"]
	if d.has("enabled_when"):
		s.enabled_when = d["enabled_when"]
	return s


func is_shown(values: Dictionary) -> bool:
	return not show_when.is_valid() or bool(show_when.call(values))


func is_enabled(values: Dictionary) -> bool:
	return not enabled_when.is_valid() or bool(enabled_when.call(values))


## Bring any candidate value into this spec's legal domain.
func sanitize(value: Variant) -> Variant:
	match type:
		Type.FLOAT:
			var v := float(value)
			if wrap:
				return wrapf(v, min_value, max_value)
			return clampf(v, hard_min, hard_max)
		Type.INT:
			return int(roundf(clampf(float(value), hard_min, hard_max)))
		Type.BOOL:
			return bool(value)
		Type.ENUM:
			var iv := int(value)
			return iv if enum_values.has(iv) else default_value
	return value
