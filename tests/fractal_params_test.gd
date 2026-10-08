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
	check_approx(p.detail, 1.0, "detail default")
	check_approx(p.detail_range, 10.0, "detail_range default")
	check_approx(p.detail_falloff, 0.0, "detail falloff is off by default")
	check_approx(p.min_render_scale, 0.25, "min_render_scale default")
	check_eq(p.max_steps, 128, "max_steps default")
	check_eq([p.coarse_steps(), p.fine_steps()], [96, 32], "the default budget is the original 96 + 32")

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
		func(): p.detail = 2.0,
		func(): p.detail_range = 50.0,
		func(): p.detail_falloff = 1.0,
		func(): p.min_render_scale = 0.5,
		func(): p.max_steps = 256,
	]:
		var fired := [false]
		var cb := func(): fired[0] = true
		p.changed.connect(cb)
		setter.call()
		p.changed.disconnect(cb)
		check(fired[0], "a setter emitted changed")

	# the renderer options clamp to their ranges
	var q := FractalParams.new()
	q.detail = 100.0
	check_approx(q.detail, FractalParams.DETAIL_MAX, "detail clamps high")
	q.detail_falloff = -1.0
	check_approx(q.detail_falloff, 0.0, "falloff clamps at 0")
	q.min_render_scale = 0.0
	check_approx(q.min_render_scale, FractalParams.RENDER_SCALE_FLOOR, "min render scale clamps low")
	q.max_steps = 100000
	check_eq(q.max_steps, FractalParams.MAX_STEPS_MAX, "max steps clamps high")
	q.max_steps = 200
	check_eq(q.coarse_steps() + q.fine_steps(), 200, "the budget splits without losing a step")

	# hit_epsilon: the plain cone by default, coarsened past the range
	var e := FractalParams.new()
	check_approx(e.hit_epsilon(4.0, 0.5), 0.000025 * 4.0, "defaults give precision * t", 1e-12)
	e.detail = 2.0
	check_approx(e.hit_epsilon(4.0, 0.5), 0.000025 * 2.0, "detail 2 halves it", 1e-12)
	e.detail = 1.0
	e.detail_falloff = 2.0
	e.detail_range = 4.0          # start = 4 * 0.5 = 2
	check_approx(e.hit_epsilon(1.5, 0.5), 0.000025 * 1.5, "inside the range: unchanged", 1e-12)
	check_approx(e.hit_epsilon(6.0, 0.5), 0.000025 * 6.0 * 9.0, "past it: x (t / start)^falloff", 1e-12)
	check(e.hit_epsilon(6.0, 0.0) > 0.0 and is_finite(e.hit_epsilon(6.0, 0.0)),
		"a camera on the surface stays finite")
