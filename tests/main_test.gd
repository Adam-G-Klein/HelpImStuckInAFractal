extends "res://tests/test_case.gd"


func run() -> void:
	var settings: Node = root.get_node("Settings")
	var original_sens: float = settings.mouse_sensitivity
	settings.config_path = "user://main_test_settings.cfg"

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

	# save and load: the buttons open the panels; the real save path round-trips
	var files: WorkspaceFiles = main.workspace_files()
	check(files != null, "Main owns a WorkspaceFiles")
	check(main.panel.save_button.pressed.is_connected(files.prompt_save), "Save opens the save panel")
	check(main.panel.load_button.pressed.is_connected(files.prompt_load), "Load opens the open panel")
	check_eq(main.panel.file_label.text, "\u2014", "no file is current at startup")

	var tmp := "user://main_test_view.json"
	main.params.camera_mode = FractalParams.CameraMode.FLY
	main.params.fold_limit = 0.72
	main.camera.speed_factor = 2.0
	main.save_view_to(tmp)
	check_eq(files.current_path, tmp, "a save that worked becomes current")
	check_eq(main.panel.file_label.text, "main_test_view.json", "and the panel names it")
	main.params.fold_limit = 0.3
	main.camera.speed_factor = 1.0
	main.load_view_from(tmp)
	check_approx(main.params.fold_limit, 0.72, "loading restores the shape")
	check_approx(main.camera.speed_factor, 2.0, "and the camera")
	check(main.panel.status_label.text.begins_with("Loaded"), "the panel reports the load: %s" % main.panel.status_label.text)
	main.load_view_from("user://no_such_view.json")
	check_eq(files.current_path, tmp, "a failed load does not change the current file")
	check(main.panel.status_label.text.begins_with("Load failed"), "and says it failed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# mouse events reach Main through the real GUI pass: the full-window view
	# must not swallow them (it did, so captured mouse-look never turned the view)
	check_eq(main.view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the view ignores the mouse")
	main.params.camera_mode = FractalParams.CameraMode.ORBIT
	await frames(1)
	var fwd_before: Vector3 = main.camera.forward()
	var at := Vector2(root.size) * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	root.push_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = at + Vector2(5, 0)
	drag.relative = Vector2(5, 0)
	root.push_input(drag)
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release)
	await frames(1)
	check(not main.camera.forward().is_equal_approx(fwd_before), "a drag over the view turns the camera")

	# the sensitivity follows Settings, and a loaded view does not override it
	settings.mouse_sensitivity = 0.33
	check_approx(main.params.mouse_sensitivity, 0.33, "params follow the Settings sensitivity")
	main.panel.sens_slider.value = 0.21
	check_approx(settings.mouse_sensitivity, 0.21, "the panel slider writes Settings")
	main.params.mouse_sensitivity = 0.4
	main.save_view_to(tmp)
	main.params.mouse_sensitivity = 0.21
	main.load_view_from(tmp)
	check_approx(settings.mouse_sensitivity, 0.21, "loading a view keeps the player's sensitivity")
	check_approx(main.params.mouse_sensitivity, 0.21, "in params too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# Escape pauses and opens the pause menu; Escape again resumes
	main.params.camera_mode = FractalParams.CameraMode.FLY
	await frames(1)
	var pause = main.pause_menu()   # untyped: see menus_test.gd
	check(not pause.visible, "the pause menu starts hidden")
	await press_action("pause")
	check(paused and pause.visible, "Escape pauses and opens the pause menu")
	check_eq(pause.menu_button.text, "Back to Menu", "it offers Back to Menu")
	pause.settings_button.pressed.emit()
	check(pause.settings_menu.visible, "and Settings")
	await press_action("pause")
	check(paused and pause.visible and not pause.settings_menu.visible,
		"Escape in its settings goes back to the pause list")
	await press_action("pause")
	check(not paused and not pause.visible, "Escape again resumes")
	await press_action("pause")
	pause.resume_button.pressed.emit()
	check(not paused and not pause.visible, "so does Resume")

	# Back to Menu unpauses and swaps to the main menu
	await press_action("pause")
	pause.menu_button.pressed.emit()
	await frames(2)
	check(not paused, "Back to Menu unpauses")
	check(current_scene != null and current_scene.name == "MainMenu", "and loads the main menu")
	if current_scene:
		current_scene.queue_free()

	main.queue_free()
	await frames(1)
	settings.mouse_sensitivity = original_sens
	await frames(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://main_test_settings.cfg"))
