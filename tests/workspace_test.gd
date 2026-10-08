extends "res://tests/test_case.gd"
## Workspace: a view survives a save and a load, and a bad file changes nothing
## it cannot read.

const TMP := "user://workspace_test.json"


func run() -> void:
	# --- a round trip restores every value ---
	var params := FractalParams.new()
	params.scale = -2.29
	params.inner_radius = 0.0
	params.fold_limit = 0.72
	params.outer_radius = 0.29
	params.color_mode = 15
	params.precision = 0.00002
	params.julia_enabled = true
	params.julia_point = Vector3(-0.23, 1.512, 1.892)
	params.fast_controls = false
	params.camera_mode = FractalParams.CameraMode.ORBIT
	params.mouse_sensitivity = 0.2
	params.detail = 2.5
	params.detail_range = 40.0
	params.detail_falloff = 1.5
	params.max_steps = 256
	params.min_render_scale = 0.4
	var camera := CameraState.new()
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(1, -2, 0.5)).looking_at(Vector3(0, 0, 0.25), Vector3(0, 0, 1))
	camera.speed_factor = 3.5

	check_eq(Workspace.save_file(TMP, params, camera), OK, "the view saves")

	var p2 := FractalParams.new()
	var c2 := CameraState.make_default()
	var result := Workspace.load_file(TMP, p2, c2)
	check(result["ok"], "and loads")
	check_eq(result["warnings"], [], "with no warnings")
	check_approx(p2.scale, -2.29, "scale")
	check_approx(p2.inner_radius, 0.0, "inner radius")
	check_approx(p2.fold_limit, 0.72, "fold")
	check_approx(p2.outer_radius, 0.29, "outer radius")
	check_eq(p2.color_mode, 15, "colour mode (by site id)")
	check_approx(p2.precision, 0.00002, "precision", 1e-9)
	check(p2.julia_enabled, "julia on")
	check(p2.julia_point.is_equal_approx(Vector3(-0.23, 1.512, 1.892)), "julia point %s" % p2.julia_point)
	check(not p2.fast_controls, "fast controls")
	check_eq(p2.camera_mode, FractalParams.CameraMode.ORBIT, "camera mode")
	check_approx(p2.mouse_sensitivity, 0.2, "mouse sensitivity")
	check_approx(p2.detail, 2.5, "detail")
	check_approx(p2.detail_range, 40.0, "detail range")
	check_approx(p2.detail_falloff, 1.5, "detail falloff")
	check_eq(p2.max_steps, 256, "max steps")
	check_approx(p2.min_render_scale, 0.4, "min render scale")
	check(c2.eye().is_equal_approx(camera.eye()), "camera eye %s" % c2.eye())
	check(c2.forward().is_equal_approx(camera.forward()), "camera forward %s" % c2.forward())
	check(c2.up().is_equal_approx(camera.up()), "camera up %s" % c2.up())
	check_approx(c2.speed_factor, 3.5, "speed factor")

	# --- the file is readable JSON with the documented sections ---
	var text := FileAccess.get_file_as_string(TMP)
	var data: Dictionary = JSON.parse_string(text)
	check_eq(int(data["version"]), Workspace.VERSION, "the file carries its version")
	check_eq(data["fractal"]["camera_mode"], "orbit", "camera mode is saved by name")
	check_eq(data["fractal"]["julia_point"].size(), 3, "vectors are three-number arrays")

	# --- unknown and malformed values are skipped with a warning each ---
	var p3 := FractalParams.new()
	var c3 := CameraState.make_default()
	var eye_before := c3.eye()
	var warnings := Workspace.restore({
		"version": 1,
		"fractal": {
			"scale": -3.0,
			"color_mode": 99,
			"precision": -1.0,
			"julia_point": [1, 2],
			"sparkle": true,
		},
		"camera": {"eye": [0, 0, 0], "forward": [0, 0, 0], "up": [0, 0, 1]},
	}, p3, c3)
	check_approx(p3.scale, -3.0, "a good value still restores next to bad ones")
	check_eq(p3.color_mode, 1, "an unknown colour id is ignored")
	check_approx(p3.precision, 0.000025, "a non-positive precision is ignored", 1e-9)
	check(p3.julia_point.is_equal_approx(Vector3(-0.23, 1.512, 1.892)), "a short vector is ignored")
	check(c3.eye().is_equal_approx(eye_before), "a zero forward leaves the camera alone")
	check_eq(warnings.size(), 5, "one warning per skipped thing: %s" % [warnings])

	# --- a key the file lacks keeps the current value ---
	var p4 := FractalParams.new()
	p4.fold_limit = 0.5
	Workspace.restore({"version": 1, "fractal": {"scale": -2.5}}, p4, CameraState.make_default())
	check_approx(p4.fold_limit, 0.5, "a missing key leaves the value alone")

	# --- the renderer options are checked too ---
	var p6 := FractalParams.new()
	var w6 := Workspace.restore({"version": 1, "fractal": {
		"detail_falloff": -2.0, "max_steps": "lots", "detail": 0.0, "detail_range": 25,
	}}, p6, CameraState.make_default())
	check_approx(p6.detail_falloff, 0.0, "a negative falloff is ignored")
	check_eq(p6.max_steps, 128, "a non-number step budget is ignored")
	check_approx(p6.detail, 1.0, "a non-positive detail is ignored")
	check_approx(p6.detail_range, 25.0, "an integer range restores")
	check_eq(w6.size(), 3, "one warning each for the three bad ones: %s" % [w6])

	# --- files that cannot load change nothing ---
	var p5 := FractalParams.new()
	var missing := Workspace.load_file("user://does_not_exist.json", p5, CameraState.make_default())
	check(not missing["ok"], "a missing file fails")
	_write(TMP, "{ not json")
	check(not Workspace.load_file(TMP, p5, CameraState.make_default())["ok"], "bad JSON fails")
	_write(TMP, JSON.stringify({"version": 2, "fractal": {"scale": -4.0}}))
	check(not Workspace.load_file(TMP, p5, CameraState.make_default())["ok"], "another version fails")
	check_approx(p5.scale, -2.09, "and none of them touched the params")

	# --- the additive noise key round-trips, and its absence is null ---
	var noise_dict := {"nodes": [{"id": "position_0", "type": "position"}], "links": []}
	Workspace.save_file(TMP, params, camera, noise_dict)
	var rn := Workspace.load_file(TMP, FractalParams.new(), CameraState.make_default())
	check(rn["ok"] and rn["warnings"].is_empty(), "a save with a noise key loads with no warnings")
	check(rn["noise"] is Dictionary and (rn["noise"] as Dictionary)["nodes"].size() == 1,
		"the noise graph round-trips under 'noise'")
	Workspace.save_file(TMP, params, camera)   # no noise
	var rn2 := Workspace.load_file(TMP, FractalParams.new(), CameraState.make_default())
	check(rn2["noise"] == null, "a file without a noise key reports null, so the current graph is left alone")
	check(not FileAccess.get_file_as_string(TMP).contains("\"noise\""),
		"…and no empty noise key is written")

	# --- every committed save loads cleanly ---
	var dir := DirAccess.open("res://saves")
	check(dir != null, "res://saves exists")
	if dir != null:
		for f in dir.get_files():
			if f.get_extension() != "json":
				continue
			var r := Workspace.load_file("res://saves/" + f, FractalParams.new(), CameraState.make_default())
			check(r["ok"] and r["warnings"].is_empty(), "saves/%s loads with no warnings %s" % [f, r["warnings"]])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
