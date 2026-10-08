class_name Main
extends Node
## Wires the two resources into every child, selects the active camera from
## camera_mode, owns the mouse capture, and is the single mouse-event dispatcher.
## Also saves and loads views: WorkspaceFiles picks the file, Workspace does the
## reading and writing, and the panel shows the result. Escape pauses the tree
## and opens the PauseMenu; the mouse sensitivity follows the Settings autoload.

const MENU_SCENE := "res://src/ui/main_menu.tscn"

var params: FractalParams
var camera: CameraState

@onready var view: FractalView = $FractalView
@onready var panel: ControlsPanel = $ControlsPanel
@onready var governor: ResolutionGovernor = $ResolutionGovernor
@onready var fly: FlyCamera = $FlyCamera

var _orbit: OrbitCamera
var _marker: JuliaMarker
var _last_mode := -1
var _files: WorkspaceFiles
var _pause: PauseMenu
var _noise: NoiseWindow
var _loading := false
# toggle_panel is bound to Ctrl, which is also a chord modifier (Ctrl+S saves,
# Ctrl+P screenshots), so the panel toggles on Ctrl *release* and only when Ctrl
# was tapped alone: a bare Ctrl key-down arms this, any other key-down while held
# disarms it.
var _ctrl_armed := false


func _ready() -> void:
	params = FractalParams.new()
	camera = CameraState.make_default()

	view.setup(params, camera)
	panel.setup(params, camera)
	governor.setup(params, view)
	fly.setup(params, camera)

	_orbit = get_node_or_null("OrbitCamera")
	if _orbit:
		_orbit.setup(params, camera, view)
	_marker = get_node_or_null("JuliaMarker")
	if _marker:
		_marker.setup(params, camera, view)

	_build_workspace_files()
	_build_pause_menu()
	_build_noise_window()

	# The sensitivity is the player's, not the view's: Settings owns it, and the
	# panel's slider writes through params back into Settings.
	params.mouse_sensitivity = Settings.mouse_sensitivity
	Settings.changed.connect(func(): params.mouse_sensitivity = Settings.mouse_sensitivity)
	params.changed.connect(_sync_sensitivity_to_settings)

	panel.visible = false
	params.changed.connect(_apply_mode)
	camera.changed.connect(func(): governor.mark_changed())
	_apply_mode()


func workspace_files() -> WorkspaceFiles:
	return _files


func pause_menu() -> PauseMenu:
	return _pause


func noise_window() -> NoiseWindow:
	return _noise


## The noise-field editor lives in an embedded window Main owns. Opening it frees
## the mouse (like the Q panel); a click in the view in Fly mode closes it and the
## panel and recaptures.
func _build_noise_window() -> void:
	_noise = NoiseWindow.new()
	_noise.name = "NoiseWindow"
	add_child(_noise)
	_noise.setup(view)
	_noise.close_requested.connect(_update_mouse)
	panel.noise_button.pressed.connect(_toggle_noise)


func _toggle_noise() -> void:
	_noise.toggle()
	_update_mouse()


func _build_pause_menu() -> void:
	_pause = PauseMenu.new()
	_pause.name = "PauseMenu"
	add_child(_pause)
	_pause.resume_requested.connect(resume)
	_pause.menu_requested.connect(back_to_menu)


func pause() -> void:
	get_tree().paused = true
	_pause.open()
	_update_mouse()


func resume() -> void:
	_pause.close()
	get_tree().paused = false
	_update_mouse()


func back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _sync_sensitivity_to_settings() -> void:
	if not _loading:
		Settings.mouse_sensitivity = params.mouse_sensitivity


## The buttons and the quick-save key only choose a file; the saving and
## loading happen here, and the chosen file becomes current only if it worked.
func _build_workspace_files() -> void:
	_files = WorkspaceFiles.new()
	_files.name = "WorkspaceFiles"
	add_child(_files)
	_files.save_to.connect(save_view_to)
	_files.load_from.connect(load_view_from)
	_files.current_changed.connect(panel.show_file)
	_files.prompting.connect(_on_prompting)
	panel.save_button.pressed.connect(_files.prompt_save)
	panel.load_button.pressed.connect(_files.prompt_load)
	var directory := WorkspaceFiles.directory()
	if directory != WorkspaceFiles.REPO_DIR:
		_report("Saves go to %s: this build cannot write into the project." % directory)
	elif WorkspaceFiles.ensure_directory() != OK:
		_report("Could not create %s; the file panel opens at your home folder." % directory)


func save_view_to(path: String) -> void:
	var noise: Dictionary = _noise.to_dict() if _noise != null else {}
	var err := Workspace.save_file(path, params, camera, noise)
	if err != OK:
		_report("Save failed (error %d): %s" % [err, path])
		return
	_files.note_saved(path)
	_report("Saved %s" % path.get_file())


func load_view_from(path: String) -> void:
	# A saved view carries a sensitivity too, but the player's setting wins.
	_loading = true
	var result := Workspace.load_file(path, params, camera)
	_loading = false
	params.mouse_sensitivity = Settings.mouse_sensitivity
	var warnings: Array = result["warnings"]
	if not result["ok"]:
		_report("Load failed: %s" % warnings[0])
		return
	_files.note_loaded(path)
	# A file with a "noise" section replaces the field; one without leaves it alone.
	var noise: Variant = result.get("noise", null)
	if noise is Dictionary and _noise != null:
		var noise_warnings := _noise.apply_dict(noise)
		for w in noise_warnings:
			warnings.append("noise: %s" % w)
	# The camera moved after the mode was applied, so re-centre the orbit on it.
	if _orbit and params.camera_mode == FractalParams.CameraMode.ORBIT:
		_orbit.enter()
	if warnings.is_empty():
		_report("Loaded %s" % path.get_file())
	else:
		_report("Loaded %s with %d warning(s): %s" % [path.get_file(), warnings.size(), "; ".join(warnings)])


## Cmd/Ctrl+P: put the fractal (without the panel or other UI) on the clipboard.
func copy_screenshot() -> void:
	var err := ClipboardImage.copy(view.capture())
	if err == OK:
		_report("Screenshot copied to clipboard")
	else:
		_report("Could not copy screenshot: %s" % error_string(err))


func _report(line: String) -> void:
	print(line)
	panel.show_status(line)


## A file panel is opening (possibly from Cmd+S with the mouse captured): free
## the mouse so the panel can be used.
func _on_prompting() -> void:
	panel.visible = true
	_update_mouse()


func _apply_mode() -> void:
	var is_fly := params.camera_mode == FractalParams.CameraMode.FLY
	fly.enabled = is_fly
	if _orbit:
		_orbit.enabled = not is_fly
		# enter() only when the mode actually changed, not on every slider move
		if not is_fly and params.camera_mode != _last_mode:
			_orbit.enter()
	_last_mode = params.camera_mode
	_update_mouse()


func _update_mouse() -> void:
	var capture := params.camera_mode == FractalParams.CameraMode.FLY \
			and not panel.visible and not _pause.visible \
			and not (_noise != null and _noise.visible)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE)


func _active_camera() -> Node:
	return fly if params.camera_mode == FractalParams.CameraMode.FLY else _orbit


# The only mouse dispatcher: Ctrl tap -> Escape/screenshot -> JuliaMarker -> camera.
# (Paused, this does not run; the PauseMenu takes Escape instead.)
func _unhandled_input(event: InputEvent) -> void:
	# 1. A Ctrl tap (down then up with no other key between) toggles the panel.
	# Ctrl is also a chord modifier (Ctrl+S quick-saves, Ctrl+P screenshots), so
	# we toggle on *release* and only when Ctrl was tapped alone: a bare Ctrl
	# key-down arms it, any other key-down disarms it. This runs before the
	# action checks below so a chord's second key (e.g. P) still disarms even
	# though copy_screenshot consumes it. Ignored while a panel text field has
	# focus. is_action_pressed can't express "release with no chord", so we read
	# the Ctrl key event directly; toggle_panel stays defined for the story.
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_CTRL:
			if event.pressed:
				_ctrl_armed = not panel.text_field_has_focus()
			elif _ctrl_armed:
				_ctrl_armed = false
				panel.visible = not panel.visible
				_update_mouse()
				get_viewport().set_input_as_handled()
				return
		elif event.pressed:
			_ctrl_armed = false   # any other key pressed while Ctrl is held disarms

	if event.is_action_pressed("pause"):
		pause()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("copy_screenshot"):
		copy_screenshot()
		get_viewport().set_input_as_handled()
		return

	# 1b. N toggles the noise editor (ignored while a panel text field has focus;
	# the editor's own spin boxes live in its window and consume their own keys).
	if event.is_action_pressed("toggle_noise_editor"):
		if panel.text_field_has_focus():
			return
		_toggle_noise()
		get_viewport().set_input_as_handled()
		return

	# 2. Julia marker drag, only while the mouse is free
	if _marker and params.julia_enabled and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _marker.begin_drag(event.position):
					get_viewport().set_input_as_handled()
					return
			else:
				_marker.end_drag()
		elif event is InputEventMouseMotion and _marker.is_dragging():
			_marker.update_drag(event.position)
			get_viewport().set_input_as_handled()
			return

	# 3. click outside the panel in FLY mode while free: hide panel, recapture.
	# (The panel consumes clicks inside itself, so a click reaching here is outside.)
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and params.camera_mode == FractalParams.CameraMode.FLY \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		panel.visible = false
		if _noise != null:
			_noise.close()
		_update_mouse()
		get_viewport().set_input_as_handled()
		return

	# 4. the active camera handles the rest (look when captured, wheel, orbit drags)
	var cam_node := _active_camera()
	if cam_node and cam_node.handle_event(event):
		get_viewport().set_input_as_handled()
