extends "res://tests/test_case.gd"


func run() -> void:
	var p := FractalParams.new()

	# defaults (the site's defaults)
	check_approx(p.scale, -2.09, "scale default")
	check_approx(p.inner_radius, 0.7, "inner_radius default")
	check_approx(p.fold_limit, 1.0, "fold_limit default")
	check_approx(p.outer_radius, 1.0, "outer_radius default")
	check_eq(p.color_mode, 1, "color_mode default is Ice Fractal")
	check_approx(p.precision, 0.000025, "precision default", 1e-9)
	check_eq(p.julia_enabled, false, "julia off by default")
	check(p.julia_point.is_equal_approx(Vector3(-0.23, 1.512, 1.892)), "julia_point default")
	check_eq(p.fast_controls, true, "fast_controls on by default")
	check_eq(p.camera_mode, FractalParams.CameraMode.FLY, "camera starts in fly mode")
	check_approx(p.mouse_sensitivity, 0.1, "mouse_sensitivity default")

	# the thirteen colour ids, in dropdown order
	check_eq(p.COLOR_MODE_IDS, [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14], "colour id order")
	check_eq(p.COLOR_MODE_NAMES.size(), 13, "thirteen colour names")
	check_eq(p.COLOR_MODE_NAMES[0], "Grayscale", "first colour name")
	check_eq(p.COLOR_MODE_NAMES[1], "Ice Fractal", "second colour name")
	check_eq(p.COLOR_MODE_NAMES[12], "Gold", "last colour name")

	# every setter emits `changed`
	for setter in [
		func(): p.scale = -3.0,
		func(): p.inner_radius = 0.5,
		func(): p.fold_limit = 0.8,
		func(): p.outer_radius = 0.9,
		func(): p.color_mode = 2,
		func(): p.precision = 0.0001,
		func(): p.julia_enabled = true,
		func(): p.julia_point = Vector3(1, 2, 3),
		func(): p.fast_controls = false,
		func(): p.camera_mode = FractalParams.CameraMode.ORBIT,
		func(): p.mouse_sensitivity = 0.2,
	]:
		var fired := [false]
		var cb := func(): fired[0] = true
		p.changed.connect(cb)
		setter.call()
		p.changed.disconnect(cb)
		check(fired[0], "a setter emitted changed")
