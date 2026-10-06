extends "res://tests/test_case.gd"


func run() -> void:
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await frames(2)

	var panel: ControlsPanel = main.get_node("ControlsPanel")
	var fly: FlyCamera = main.get_node("FlyCamera")

	# panel hidden by default, fly camera active
	check(not panel.visible, "panel starts hidden")
	check(fly.enabled, "fly camera is enabled in FLY mode")

	# Q toggles the panel
	await press_action("toggle_panel")
	check(panel.visible, "Q shows the panel")
	await press_action("toggle_panel")
	check(not panel.visible, "Q hides it again")

	# switching to ORBIT disables the fly camera and enables orbit
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	check(not fly.enabled, "fly camera is disabled in ORBIT mode")
	var orbit = main.get_node_or_null("OrbitCamera")
	if orbit != null:
		check(orbit.enabled, "orbit camera is enabled in ORBIT mode")

	# (bug 5a) a left click in FLY mode with the panel open hides it and recaptures
	main.params.camera_mode = FractalParams.CameraMode.FLY
	await frames(1)
	main.panel.visible = true
	main._update_mouse()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 300)
	main._unhandled_input(click)
	check(not main.panel.visible, "a click in fly mode hides the open panel")

	# (bug 5b) changing a non-mode param in orbit mode must not re-run enter()
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	var orbit2 = main.get_node_or_null("OrbitCamera")
	if orbit2 != null:
		orbit2.center = Vector3(9, 9, 9)   # sentinel
		main.params.scale = -3.0           # a non-mode change
		await frames(1)
		check(orbit2.center.is_equal_approx(Vector3(9, 9, 9)),
			"a slider change in orbit mode does not recenter")

	main.queue_free()
	await frames(1)
