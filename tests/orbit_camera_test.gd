extends "res://tests/test_case.gd"


func run() -> void:
	var params := FractalParams.new()
	var cam := CameraState.make_default()
	var view: FractalView = load("res://src/fractal/fractal_view.tscn").instantiate()
	root.add_child(view)
	view.size = Vector2(1280, 800)
	view.setup(params, cam)
	var orbit := OrbitCamera.new()
	root.add_child(orbit)
	orbit.setup(params, cam, view)
	orbit.enabled = true
	orbit.center = Vector3.ZERO
	await frames(1)

	# --- rotation keeps the distance to the centre ---
	var d0 := cam.eye().distance_to(orbit.center)
	orbit.rotate_view(50.0, 20.0)
	check_approx(cam.eye().distance_to(orbit.center), d0, "rotation preserves orbit distance", 1e-4)

	# --- a vertical drag actually changes the eye's height over the centre ---
	var z0 := (cam.eye() - orbit.center).z
	orbit.rotate_view(0.0, 50.0)
	check(absf((cam.eye() - orbit.center).z - z0) > 0.1,
		"vertical drag changes the eye height over centre (got dz %s)" % ((cam.eye() - orbit.center).z - z0))

	# --- pan moves camera and centre together ---
	var eye_before := cam.eye()
	var center_before := orbit.center
	orbit.pan(30.0, -10.0)
	check((cam.eye() - eye_before).is_equal_approx(orbit.center - center_before),
		"pan moves camera and centre by the same vector")

	# --- dolly changes the distance only, keeps direction ---
	var dist_before := cam.eye().distance_to(orbit.center)
	var dir_before := (cam.eye() - orbit.center).normalized()
	orbit.dolly(40.0)
	check(absf(cam.eye().distance_to(orbit.center) - dist_before) > 1e-3, "dolly changes the distance")
	check((cam.eye() - orbit.center).normalized().is_equal_approx(dir_before),
		"dolly keeps the view direction")

	# --- recenter helper ---
	orbit.recenter_on(Vector3(0.1, 0.2, 0.3))
	check(orbit.center.is_equal_approx(Vector3(0.1, 0.2, 0.3)), "recenter sets the centre to the hit")

	# --- handle_event: a left-drag rotates the camera ---
	orbit.center = Vector3.ZERO
	var eye0 := cam.eye()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = Vector2(640, 400)
	check(orbit.handle_event(press), "left press is consumed")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(60, 0); motion.position = Vector2(700, 400)
	orbit.handle_event(motion)
	check(not cam.eye().is_equal_approx(eye0), "left-drag rotates the camera")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false; release.position = Vector2(700, 400)
	orbit.handle_event(release)

	# --- handle_event: the wheel zooms (changes the distance) ---
	var dpre := cam.eye().distance_to(orbit.center)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.position = Vector2(640, 400)
	orbit.handle_event(wheel)
	check(absf(cam.eye().distance_to(orbit.center) - dpre) > 1e-3, "wheel zoom changes the distance")

	# --- handle_event: a click (press+release, no drag) recentres ---
	orbit.center = Vector3(5, 5, 5)
	var cp := InputEventMouseButton.new()
	cp.button_index = MOUSE_BUTTON_LEFT; cp.pressed = true; cp.position = Vector2(640, 400)
	orbit.handle_event(cp)
	var cr := InputEventMouseButton.new()
	cr.button_index = MOUSE_BUTTON_LEFT; cr.pressed = false; cr.position = Vector2(640, 400)
	orbit.handle_event(cr)
	check(not orbit.center.is_equal_approx(Vector3(5, 5, 5)), "a click recentres (onto a hit or the origin)")

	orbit.queue_free()
	view.queue_free()
	await frames(1)
