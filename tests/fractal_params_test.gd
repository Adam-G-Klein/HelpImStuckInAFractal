extends "res://tests/test_case.gd"


func run() -> void:
	var p := FractalParams.new()

	# defaults (the site's defaults, now by catalogue id)
	check_approx(p.box_scale, -2.09, "box_scale default")
	check_approx(p.min_radius, 0.7, "min_radius default")
	check_approx(p.fold_limit, 1.0, "fold_limit default")
	check_approx(p.fixed_radius, 1.0, "fixed_radius default")
	check_eq(p.fold_order, 0, "fold_order default is Box -> Sphere")
	check_approx(p.w, 0.0, "w default is 0 (today's 3D box)")
	check_eq(p.julia_all, false, "julia_all off by default")
	check_eq(p.julia_0, false, "julia_0 off")
	check_approx(p.c_0, -0.23, "c_0 default")
	check_approx(p.c_1, 1.512, "c_1 default")
	check_approx(p.c_2, 1.892, "c_2 default")
	check_approx(p.c_3, 0.0, "c_3 default")
	check_approx(p.iter_rot_xy, 0.0, "iter_rot_xy default")
	check_approx(p.iter_rot_zw, 0.0, "iter_rot_zw default")
	check_eq(p.color_mode, 1, "color_mode default is Ice Fractal")
	check_approx(p.precision, 0.000025, "precision default", 1e-9)
	check_eq(p.fast_controls, true, "fast_controls on by default")
	check_eq(p.camera_mode, FractalParams.CameraMode.FLY, "camera starts in fly mode")
	check_approx(p.mouse_sensitivity, 0.1, "mouse_sensitivity default")

	# the helpers
	check(p.julia_point().is_equal_approx(Vector3(-0.23, 1.512, 1.892)), "julia_point() is (c_0, c_1, c_2)")
	check_eq(p.julia_enabled(), false, "julia_enabled() follows julia_all")
	p.julia_all = true
	check_eq(p.julia_enabled(), true, "julia_enabled() true when julia_all is on")
	p.julia_all = false

	# the thirteen colour ids, in dropdown order
	check_eq(p.COLOR_MODE_IDS, [0, 1, 2, 3, 4, 8, 15, 5, 6, 7, 16, 9, 14], "colour id order")
	check_eq(p.COLOR_MODE_NAMES.size(), 13, "thirteen colour names")

	# --- apply_resolved emits once, only on a difference ---
	var fires := [0]
	var cb := func(): fires[0] += 1
	p.changed.connect(cb)

	p.apply_resolved({&"box_scale": -1.5, &"fold_limit": 2.0, &"color_mode": 2})
	check_eq(fires[0], 1, "apply_resolved emits once for a batch of changes")
	check_approx(p.box_scale, -1.5, "and wrote box_scale")
	check_approx(p.fold_limit, 2.0, "and fold_limit")
	check_eq(p.color_mode, 2, "and color_mode")

	fires[0] = 0
	p.apply_resolved({&"box_scale": -1.5, &"fold_limit": 2.0, &"color_mode": 2})
	check_eq(fires[0], 0, "re-applying the same values emits nothing")

	fires[0] = 0
	p.apply_resolved({&"w": 0.5})
	check_eq(fires[0], 1, "a partial dict that changes one field emits once")
	check_approx(p.w, 0.5, "and wrote only w")
	check_approx(p.fold_limit, 2.0, "leaving the rest alone")

	p.changed.disconnect(cb)

	# every preference setter still emits `changed`
	for setter in [
		func(): p.fast_controls = false,
		func(): p.camera_mode = FractalParams.CameraMode.ORBIT,
		func(): p.mouse_sensitivity = 0.2,
	]:
		var fired := [false]
		var one := func(): fired[0] = true
		p.changed.connect(one)
		setter.call()
		p.changed.disconnect(one)
		check(fired[0], "a preference setter emitted changed")
