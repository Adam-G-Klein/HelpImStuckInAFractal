class_name Workspace
extends RefCounted
## Saving and loading a view as JSON: every FractalParams value and the camera.
##
## What is saved: the shape (scale, the three radii), the colour mode, the
## precision, Julia mode and its point, fast controls, the camera mode, the
## mouse sensitivity, the renderer options (level of detail, step budget and
## minimum render scale), and the camera's eye, orientation and speed factor. What
## is not: anything derivable (the orbit centre, the governor's render scale,
## rendered pixels).
##
## Loading never fails on unfamiliar content. An unknown or malformed key is
## skipped and reported as a warning string, and a key the file does not have
## leaves the current value alone, so a file written by a newer build still
## restores what this one understands. VERSION only changes if an existing key
## changes meaning; a new key is additive.

const VERSION := 1

## The FractalParams values written under "fractal", in file order. Colour mode
## is stored as the site's id, camera mode by name, the Julia point as [x, y, z].
const PARAM_KEYS: Array[String] = [
	"scale", "inner_radius", "fold_limit", "outer_radius", "color_mode",
	"precision", "julia_enabled", "julia_point", "fast_controls",
	"camera_mode", "mouse_sensitivity",
	"detail", "detail_range", "detail_falloff", "max_steps", "min_render_scale",
]
const CAMERA_MODE_NAMES: Array[String] = ["fly", "orbit"]


## Snapshot the view. Pure: it reads, it does not change anything. `noise` is the
## noise graph's dict; when non-empty it is stored under an additive "noise" key,
## which an older build simply ignores on load.
static func capture(params: FractalParams, camera: CameraState, noise := {}) -> Dictionary:
	var fractal := {}
	for key in PARAM_KEYS:
		var value: Variant = params.get(key)
		if key == "camera_mode":
			value = CAMERA_MODE_NAMES[int(value)]
		elif value is Vector3:
			value = _vec_to_array(value)
		fractal[key] = value
	var out := {
		"version": VERSION,
		"fractal": fractal,
		"camera": {
			"eye": _vec_to_array(camera.eye()),
			"forward": _vec_to_array(camera.forward()),
			"up": _vec_to_array(camera.up()),
			"speed_factor": camera.speed_factor,
		},
	}
	if not noise.is_empty():
		out["noise"] = noise
	return out


## Apply a capture. Returns the warnings, one string per thing it skipped.
## Each value is checked before it is written, so a malformed file changes
## only the values it got right.
static func restore(data: Dictionary, params: FractalParams, camera: CameraState) -> Array:
	var warnings: Array = []

	var fractal: Variant = data.get("fractal", {})
	if fractal is Dictionary:
		for key in fractal:
			if not PARAM_KEYS.has(key):
				warnings.append("Unknown fractal value '%s' ignored" % key)
				continue
			var value: Variant = _parse_param(key, fractal[key])
			if value == null:
				warnings.append("Malformed '%s' ignored" % key)
				continue
			params.set(key, value)
	else:
		warnings.append("Malformed fractal section ignored")

	var cam: Variant = data.get("camera", {})
	if cam is Dictionary:
		_restore_camera(cam, camera, warnings)
	else:
		warnings.append("Malformed camera section ignored")

	return warnings


## Write a capture to `path` as indented JSON. `noise`, when non-empty, is stored
## under the "noise" key.
static func save_file(path: String, params: FractalParams, camera: CameraState, noise := {}) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(capture(params, camera, noise), "\t", false))
	file.close()
	return OK


## Read `path` and restore it. Never throws: a missing file, unreadable file,
## bad JSON or unsupported version return `ok == false` with a warning and
## change nothing.
static func load_file(path: String, params: FractalParams, camera: CameraState) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("No saved view at %s" % path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("Could not read %s (error %d)" % [path, FileAccess.get_open_error()])
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse() instead of JSON.parse_string(): the static helper
	# pushes an engine error on malformed input, and a bad file is an expected
	# outcome here, not a bug.
	var json := JSON.new()
	if json.parse(text) != OK:
		return _failure("%s is not valid JSON (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
	var data: Variant = json.data
	if not (data is Dictionary):
		return _failure("%s does not contain a saved view" % path)
	var version := int((data as Dictionary).get("version", 0))
	if version != VERSION:
		return _failure("Save version %d is not supported (this build reads version %d)" % [version, VERSION])
	# The noise graph is handed back raw for the caller to apply to its editor; a
	# file without the key leaves the current graph alone (null here means "none").
	var noise: Variant = (data as Dictionary).get("noise", null)
	if not (noise is Dictionary):
		noise = null
	return {"ok": true, "warnings": restore(data, params, camera), "noise": noise}


## Write a graph-only noise file: {"version": VERSION, "noise": {...}}. The editor
## uses this for its own Save…; a view save embeds the same dict under "noise".
static func save_noise_file(path: String, noise_dict: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "noise": noise_dict}, "\t", false))
	file.close()
	return OK


## Read a graph-only noise file. Returns {ok, warnings, noise} where `noise` is the
## raw dict (the caller builds the graph) or {} on failure. Never throws.
static func load_noise_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "warnings": ["No noise graph at %s" % path], "noise": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "warnings": ["Could not read %s" % path], "noise": {}}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "warnings": ["%s is not valid JSON" % path], "noise": {}}
	var data: Variant = json.data
	if not (data is Dictionary):
		return {"ok": false, "warnings": ["%s does not contain a noise graph" % path], "noise": {}}
	var version := int((data as Dictionary).get("version", 0))
	if version != VERSION:
		return {"ok": false, "warnings": ["Noise file version %d is not supported" % version], "noise": {}}
	var noise: Variant = (data as Dictionary).get("noise", {})
	if not (noise is Dictionary):
		return {"ok": false, "warnings": ["%s has no noise section" % path], "noise": {}}
	return {"ok": true, "warnings": [], "noise": noise}


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "warnings": [message]}


## The typed value for one "fractal" key, or null when it is malformed.
static func _parse_param(key: String, raw: Variant) -> Variant:
	match key:
		"julia_enabled", "fast_controls":
			return raw if raw is bool else null
		"julia_point":
			return _array_to_vec(raw)
		"color_mode":
			if not (raw is float or raw is int):
				return null
			var id := int(raw)
			return id if FractalParams.COLOR_MODE_IDS.has(id) else null
		"camera_mode":
			var index := CAMERA_MODE_NAMES.find(String(raw)) if raw is String else -1
			return index if index >= 0 else null
		"precision", "mouse_sensitivity", "detail", "detail_range", "min_render_scale":
			return float(raw) if (raw is float or raw is int) and float(raw) > 0.0 else null
		"detail_falloff":
			return float(raw) if (raw is float or raw is int) and float(raw) >= 0.0 else null
		"max_steps":
			return int(raw) if (raw is float or raw is int) and float(raw) >= 1.0 else null
		_:
			return float(raw) if (raw is float or raw is int) else null


static func _restore_camera(cam: Dictionary, camera: CameraState, warnings: Array) -> void:
	var eye: Variant = _array_to_vec(cam.get("eye", null))
	var forward: Variant = _array_to_vec(cam.get("forward", null))
	var up: Variant = _array_to_vec(cam.get("up", null))
	if eye != null and forward != null and up != null:
		var f := (forward as Vector3).normalized()
		var u := (up as Vector3).normalized()
		if f.is_zero_approx() or u.is_zero_approx() or absf(f.dot(u)) > 0.999:
			warnings.append("Malformed camera orientation ignored")
		else:
			camera.transform = Transform3D(Basis.IDENTITY, eye).looking_at(eye + f, u)
	elif cam.has("eye") or cam.has("forward") or cam.has("up"):
		warnings.append("Malformed camera position ignored")
	if cam.has("speed_factor"):
		var s: Variant = cam["speed_factor"]
		if (s is float or s is int) and float(s) > 0.0:
			camera.speed_factor = float(s)
		else:
			warnings.append("Malformed camera speed_factor ignored")


## Vector3 is single precision, so its components are rounded to the seven
## significant digits a float32 actually holds; otherwise -0.23 is written as
## -0.230000004172325.
static func _vec_to_array(v: Vector3) -> Array:
	return [_tidy(v.x), _tidy(v.y), _tidy(v.z)]


static func _tidy(x: float) -> float:
	if x == 0.0 or not is_finite(x):
		return x
	var decimals := 7 - int(ceil(log(absf(x)) / log(10.0)))
	var p := pow(10.0, decimals)
	return roundf(x * p) / p


## A Vector3 from a three-number array, or null.
static func _array_to_vec(raw: Variant) -> Variant:
	if not (raw is Array) or raw.size() != 3:
		return null
	for n in raw:
		if not (n is float or n is int):
			return null
	return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
